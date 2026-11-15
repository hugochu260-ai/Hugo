#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
drive_loop_smooth.py — 平順低延遲版 Jetson VLN 自動導航控制器
======================================================================
專門解決舊版 drive_loop.py「郁 0.2 秒、停 0.8 秒（郁下停一下）」及高延遲問題：

【舊版卡頓三大元兇】
1. 同步阻塞 Pulse-and-Stop：舊版每發一次 ONA 行 0.2 秒就強制發 ONF 停車，
   然後停低乾等 4G + Cloudflare 傳相返屋企台機行 LightNav-0（耗時 600–1100ms），
   導致 80% 時間部車都係死停狀態。
2. 圖片過大且每次重連 TLS：舊版上傳 640x480 q85（約 50–90KB）且無複用連線；
   其實 LightNav-0 官方 eval_config.json 原生輸入係 448x256（16:9），
   縮至 448x256 q72 只需約 12–16KB，4G 上傳時間即減超過一半！
3. 單幀誤判與轉向過度：舊版對單次 stop 反應過敏，且無配合斜坡自動減速。

【新版雙線程非同步租約架構（Async Inference + 20Hz Local Safety Loop）】
- 線程 A（VLM 視覺推論線程）：
  用 HTTP Keep-Alive Session 持續上傳最新 448x256 影格，每次推論成功即續期
  「移動意圖租約（Command Lease，預設有效期 1.15 秒）」，期間唔會無故煞停馬達！
- 線程 B（20Hz / 每 50ms 本地平滑控制與雷達防撞線程）：
  * 直路巡航（forward）：只要租約未過期且本地 STL-27L 雷達前方 >= 1.0m，
    保持連續平順推進（零急停頓挫！）。
  * 斜坡慢行保護（speed_factor < 1.0）：當手機 App 傾斜感測器偵測到上下斜坡，
    自動切換柔和佔空比脈衝降速（例如落斜 48% 速度），平穩落坡唔衝車。
  * 微調轉向（left / right）：採用柔和轉向步幅，防止原地打轉過頭。
  * 本地 50ms 即時煞停防線：一旦雷達 < 1.0m、網路中斷令租約過期（>1.15s）、
    或連續 3 次確認到達目標，50ms 內即刻寫入 ONF 停車！
  * 真實遙測輸出：即時寫入 /dev/shm/fyp_drive_status.json，供 App 顯示真實指令與延遲。
"""

import argparse
import base64
import json
import math
import os
import signal
import subprocess
import threading
import time
from typing import Dict, List, Optional, Tuple

try:
    import cv2
except ImportError:
    cv2 = None

try:
    import requests
except ImportError:
    requests = None


# LightNav-0 官方 checkpoint 原生解析度 (W=448, H=256)
TARGET_WIDTH = 448
TARGET_HEIGHT = 256
JPEG_QUALITY = 72

SHM_FRAME_PATH = "/dev/shm/fyp_frame.jpg"
SHM_SCANS_PATH = "/dev/shm/fyp_scans.json"
SHM_STATUS_PATH = "/dev/shm/fyp_drive_status.json"
IGNORE_RADAR_FLAG = "/home/mike_wong/drive_ignore_radar"
SPEED_FACTOR_FILE = "/dev/shm/fyp_speed_factor.txt"

CMD_PAYLOAD = {
    "forward": "ONA",
    "backward": "ONB",
    "left": "ONC",
    "right": "OND",
    "stop": "ONF",
    "safety_stop": "ONE",
}


class SharedDriveState:
    """線程安全共享狀態：連接 VLM 推論線程與 20Hz 本地馬達控制線程。"""

    def __init__(self, lease_ttl_s: float = 1.15) -> None:
        self.lock = threading.Lock()
        self.running: bool = True
        self.intent: str = "stop"
        self.lease_expires_at: float = 0.0
        self.lease_ttl_s: float = lease_ttl_s

        # 真實遙測數據（絕不偽造）
        self.seq: int = 0
        self.last_latency_ms: Optional[float] = None
        self.vlm_fps: float = 0.0
        self.visible: bool = False
        self.reason: str = "初始化中"
        self.consecutive_stops: int = 0
        self.consecutive_errors: int = 0
        self.goal_reached: bool = False

    def update_from_vlm(
        self,
        command: str,
        stop_flag: bool,
        visible: bool,
        reason: str,
        latency_ms: float,
        fps: float,
    ) -> None:
        now = time.monotonic()
        with self.lock:
            self.seq += 1
            self.last_latency_ms = round(latency_ms, 1)
            self.vlm_fps = round(fps, 2)
            self.visible = visible
            self.reason = reason or ""
            self.consecutive_errors = 0

            if stop_flag or command == "stop":
                self.consecutive_stops += 1
                # 連續 2 幀 stop 即減速待命，連續 3 幀確認任務完成自動結束
                if self.consecutive_stops >= 2:
                    self.intent = "stop"
                    self.lease_expires_at = 0.0
                if self.consecutive_stops >= 3 and "完成" in (reason or ""):
                    self.goal_reached = True
                    self.running = False
            else:
                self.consecutive_stops = 0
                self.intent = command
                self.lease_expires_at = now + self.lease_ttl_s

    def record_error(self, err_msg: str) -> None:
        with self.lock:
            self.consecutive_errors += 1
            self.reason = f"API 異常 ({self.consecutive_errors}): {err_msg}"
            if self.consecutive_errors >= 5:
                self.intent = "stop"
                self.lease_expires_at = 0.0
                self.running = False

    def snapshot(self) -> dict:
        now = time.monotonic()
        with self.lock:
            lease_valid = now < self.lease_expires_at
            effective = self.intent if lease_valid else "stop"
            return {
                "running": self.running,
                "effective_intent": effective,
                "lease_valid": lease_valid,
                "seq": self.seq,
                "latency_ms": self.last_latency_ms,
                "fps": self.vlm_fps,
                "visible": self.visible,
                "reason": self.reason,
                "goal_reached": self.goal_reached,
            }


class BleActuator:
    """負責向 BT04-A 發送 BLE 指令，避免重複寫入同一狀態造成藍牙阻塞。"""

    def __init__(self, ble_script: str = "/home/mike_wong/car_ble.py", dry_run: bool = False) -> None:
        self.ble_script = ble_script
        self.dry_run = dry_run
        self.current_wire_cmd: Optional[str] = None
        self.last_send_at: float = 0.0

    def send(self, logical_cmd: str, force: bool = False) -> None:
        wire = CMD_PAYLOAD.get(logical_cmd, "ONF")
        now = time.monotonic()
        # 相同前進指令每 0.6s 溫和續發一次即可，唔使每 50ms 狂刷 BLE，亦唔會發 ONF 煞停！
        if not force and wire == self.current_wire_cmd and (now - self.last_send_at) < 0.60:
            return
        self.current_wire_cmd = wire
        self.last_send_at = now
        if self.dry_run:
            return
        if os.path.exists(self.ble_script):
            subprocess.run(
                ["python3", self.ble_script, "raw", wire],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=1.5,
                check=False,
            )

    def emergency_stop(self) -> None:
        self.send("stop", force=True)
        time.sleep(0.05)
        self.send("safety_stop", force=True)


def read_local_lidar(obstacle_limit_m: float = 1.0) -> Tuple[Optional[float], Optional[float], List[str], bool]:
    """讀取 /dev/shm/fyp_scans.json 並進行本地 50ms 級前後障礙物檢查。"""
    if os.path.exists(IGNORE_RADAR_FLAG):
        return 5.0, 5.0, [], True

    if not os.path.exists(SHM_SCANS_PATH):
        return None, None, [], False

    try:
        mtime = os.path.getmtime(SHM_SCANS_PATH)
        if time.time() - mtime > 1.2:
            return None, None, [], False
        with open(SHM_SCANS_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        front_m = data.get("front_m")
        rear_m = data.get("rear_m")
        encoded = data.get("lidar_scans", [])
        return (
            float(front_m) if front_m is not None else None,
            float(rear_m) if rear_m is not None else None,
            encoded if isinstance(encoded, list) else [],
            True,
        )
    except Exception:
        return None, None, [], False


def read_speed_factor() -> float:
    """讀取由手機 App 斜坡監測器傳入的速度比例（預設 1.0；上下斜坡約 0.48–0.58）。"""
    try:
        if os.path.exists(SPEED_FACTOR_FILE):
            val = float(open(SPEED_FACTOR_FILE, "r", encoding="utf-8").read().strip())
            return max(0.35, min(1.0, val))
    except Exception:
        pass
    return 1.0


def load_resized_jpeg_b64() -> Optional[str]:
    """讀取最新鏡頭畫面並縮放至 LightNav-0 原生 448x256，大幅減少 4G 上傳延遲。"""
    if not os.path.exists(SHM_FRAME_PATH):
        return None
    try:
        if time.time() - os.path.getmtime(SHM_FRAME_PATH) > 2.0:
            return None
        with open(SHM_FRAME_PATH, "rb") as f:
            raw = f.read()
        if not raw:
            return None
        if cv2 is not None:
            import numpy as np
            arr = np.frombuffer(raw, dtype=np.uint8)
            img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
            if img is not None:
                resized = cv2.resize(img, (TARGET_WIDTH, TARGET_HEIGHT), interpolation=cv2.INTER_AREA)
                ok, enc = cv2.imencode(".jpg", resized, [int(cv2.IMWRITE_JPEG_QUALITY), JPEG_QUALITY])
                if ok:
                    return base64.b64encode(enc.tobytes()).decode("ascii")
        return base64.b64encode(raw).decode("ascii")
    except Exception:
        return None


def write_telemetry(payload: Dict[str, object]) -> None:
    tmp = SHM_STATUS_PATH + ".tmp"
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        os.replace(tmp, SHM_STATUS_PATH)
    except Exception:
        pass


def vlm_inference_worker(
    state: SharedDriveState,
    server_url: str,
    api_key: str,
    instruction: str,
    obstacle_m: float,
) -> None:
    """背景連續推論線程：複用 HTTPS Keep-Alive Session，無阻塞更新移動租約。"""
    if requests is None:
        state.record_error("缺少 python3-requests 套件")
        return

    base = server_url.rstrip("/")
    headers = {"Content-Type": "application/json; charset=utf-8"}
    if api_key:
        headers["X-API-Key"] = api_key

    session = requests.Session()
    try:
        session.post(f"{base}/v1/session/start", headers=headers, json={"client_id": "jetson-smooth-v2"}, timeout=10)
    except Exception as e:
        state.record_error(f"Session 啟動失敗: {e}")
        return

    fps_window: List[float] = []
    seq = 0

    while state.snapshot()["running"]:
        t0 = time.monotonic()
        img_b64 = load_resized_jpeg_b64()
        if img_b64 is None:
            time.sleep(0.06)
            continue

        _, _, scans, _ = read_local_lidar(obstacle_m)
        seq += 1
        body = {
            "seq": seq,
            "instruction": instruction,
            "image": img_b64,
            "lidar_scans": scans[:4],
        }
        try:
            resp = session.post(f"{base}/v1/drive", headers=headers, json=body, timeout=4.5)
            elapsed_ms = (time.monotonic() - t0) * 1000.0
            if resp.status_code != 200:
                state.record_error(f"HTTP {resp.status_code}")
                time.sleep(0.15)
                continue

            data = resp.json()
            now = time.monotonic()
            fps_window.append(now)
            fps_window = [t for t in fps_window if now - t <= 3.0]
            fps = len(fps_window) / 3.0 if len(fps_window) > 1 else 1.0

            state.update_from_vlm(
                command=str(data.get("command", "stop")),
                stop_flag=bool(data.get("stop", False)) or bool(data.get("goal_reached", False)),
                visible=bool(data.get("visible", False)),
                reason=str(data.get("reason") or ""),
                latency_ms=float(data.get("latency_ms") or elapsed_ms),
                fps=fps,
            )
        except Exception as e:
            state.record_error(str(e))
            time.sleep(0.15)
            continue

        # 控制推論節奏最高約 4.5 FPS（~220ms），避免塞爆 4G 上傳佇列造成排隊延遲
        spent = time.monotonic() - t0
        if spent < 0.22:
            time.sleep(0.22 - spent)

    try:
        session.post(f"{base}/v1/session/stop", headers=headers, json={}, timeout=3)
    except Exception:
        pass


def smooth_safety_control_loop(
    state: SharedDriveState,
    actuator: BleActuator,
    obstacle_m: float = 1.0,
) -> None:
    """20Hz（每 50ms）本地平滑馬達與雷達安全迴圈：消除「郁下停一下」！"""
    duty_phase = 0
    try:
        while True:
            snap = state.snapshot()
            if not snap["running"]:
                break

            front_m, rear_m, _, radar_live = read_local_lidar(obstacle_m)
            speed_factor = read_speed_factor()
            desired = snap["effective_intent"]
            blocked_reason: Optional[str] = None

            # 1. 本地即時雷達防撞否決（<50ms 反應，唔使等網路！）
            if not radar_live:
                desired = "stop"
                blocked_reason = "雷達無即時數據，安全煞停"
            elif desired == "forward" and front_m is not None and front_m < obstacle_m:
                desired = "stop"
                blocked_reason = f"前方 {front_m:.2f}m 有障礙物"
            elif desired == "backward" and rear_m is not None and rear_m < obstacle_m:
                desired = "stop"
                blocked_reason = f"後方 {rear_m:.2f}m 有障礙物"
            elif not snap["lease_valid"] and snap["seq"] > 0:
                desired = "stop"
                blocked_reason = "等待 VLN 新決策（網路延遲保護）"

            # 2. 平順馬達輸出（直路唔再每 0.2s 急停；斜坡或轉彎自動柔和調速）
            duty_phase = (duty_phase + 1) % 6  # 6 * 50ms = 300ms 微週期
            if desired == "stop":
                actuator.send("stop")
            elif desired in ("left", "right"):
                # 轉向採用 67% 柔和佔空比（200ms 轉 + 100ms 緩衝），避免轉過龍打白鴿轉
                if duty_phase < 4:
                    actuator.send(desired)
                else:
                    actuator.send("stop")
            else:
                # 直路前進／後退：平地 100% 連續順滑輸出（零急停！）；斜坡按 speed_factor 自動降速
                active_slots = max(2, round(6 * speed_factor))
                if duty_phase < active_slots:
                    actuator.send(desired)
                else:
                    actuator.send("stop")

            # 3. 輸出真實狀態供 control_daemon -> Flutter App 即時顯示
            write_telemetry({
                "type": "status",
                "driving": True,
                "command": desired,
                "latency_ms": snap["latency_ms"],
                "fps": snap["fps"],
                "visible": snap["visible"],
                "front_m": front_m,
                "rear_m": rear_m,
                "blocked_reason": blocked_reason,
                "speed_factor": speed_factor,
                "updated_ms": int(time.time() * 1000),
            })

            time.sleep(0.05)
    finally:
        actuator.emergency_stop()
        write_telemetry({
            "type": "status",
            "driving": False,
            "command": "stop",
            "goal_reached": state.snapshot()["goal_reached"],
            "updated_ms": int(time.time() * 1000),
        })


def main() -> None:
    parser = argparse.ArgumentParser(description="Smooth Async VLN Drive Controller")
    parser.add_argument("--server", default=os.environ.get("VLN_SERVER", "https://fyp.pikachumike.win"))
    parser.add_argument("--api-key", default=os.environ.get("VLN_API_KEY", ""))
    parser.add_argument("--instruction", default=os.environ.get("VLN_INSTRUCTION", "前往目標位置"))
    parser.add_argument("--obstacle-m", type=float, default=1.0)
    parser.add_argument("--lease-ttl", type=float, default=1.15)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    state = SharedDriveState(lease_ttl_s=args.lease_ttl)
    actuator = BleActuator(dry_run=args.dry_run)

    def _handle_sig(_sig, _frame):
        state.running = False

    signal.signal(signal.SIGINT, _handle_sig)
    signal.signal(signal.SIGTERM, _handle_sig)

    worker = threading.Thread(
        target=vlm_inference_worker,
        args=(state, args.server, args.api_key, args.instruction, args.obstacle_m),
        daemon=True,
    )
    worker.start()
    smooth_safety_control_loop(state, actuator, obstacle_m=args.obstacle_m)


if __name__ == "__main__":
    main()
