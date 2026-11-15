import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/car_command.dart';
import '../../models/drive_models.dart';
import '../ble_car_service.dart';
import '../radar/radar_service.dart';
import '../settings_store.dart';
import '../tilt/tilt_monitor_service.dart';
import 'jetson_control_service.dart';

/// Coordinates goal-level VLN navigation with:
/// 1) Mandatory Pre-departure User Confirmation (`pendingInstruction`).
/// 2) Zero fake telemetry — exposes only verified Jetson/Radar/BLE states & errors.
/// 3) Automatic slope slow-down & emergency rollover stop integration.
/// 4) Hardened Emergency Stop (network stop + local BLE override fallback).
class AutoDriveController extends ChangeNotifier {
  AutoDriveController({
    required this.settings,
    required this.radar,
    required this.ble,
    required this.control,
    required this.tilt,
  }) {
    control.addListener(_onControl);
    radar.addListener(_onRadar);
  }

  final SettingsStore settings;
  final RadarService radar;
  final BleCarService ble;
  final JetsonControlService control;
  final TiltMonitorService tilt;

  bool running = false;
  bool starting = false;
  String? error;
  String statusMessage = '未連接導航通道';

  /// Staged navigation destination awaiting user's explicit secondary confirmation.
  String? pendingInstruction;
  bool pendingIgnoreRadar = false;

  CarCommand? get lastCommand {
    final raw = control.realDecision?.command;
    return CarCommand.fromApi(raw);
  }

  DriveDecision? get lastDecision => control.realDecision;
  double? get realFps => control.realJetsonFps;
  double? get frontM => radar.isLive ? radar.frontM : control.realDecision?.frontM;
  double? get rearM => radar.isLive ? radar.rearM : control.realDecision?.rearM;
  bool get controlConnected => control.connected;

  /// Step 1 of Proposal Section 6: Stage destination & ask user for confirmation!
  void requestConfirmation(String destination, {bool ignoreRadar = false}) {
    final clean = destination.trim();
    if (clean.isEmpty) return;
    pendingInstruction = clean;
    pendingIgnoreRadar = ignoreRadar;
    error = null;
    notifyListeners();
  }

  void cancelConfirmation() {
    pendingInstruction = null;
    pendingIgnoreRadar = false;
    notifyListeners();
  }

  Future<bool> confirmAndStart() async {
    final target = pendingInstruction;
    final ignore = pendingIgnoreRadar;
    pendingInstruction = null;
    pendingIgnoreRadar = false;
    notifyListeners();
    if (target == null || target.isEmpty) return false;
    return startConfirmed(instructionOverride: target, ignoreRadar: ignore);
  }

  /// Executes navigation ONLY after explicit user confirmation.
  Future<bool> startConfirmed({
    String? instructionOverride,
    bool ignoreRadar = false,
  }) async {
    if (running || starting) return running;
    if (tilt.isEmergency) {
      error = '目前偵測到嚴重傾斜或跌倒風險，安全系統已禁止啟動移動';
      statusMessage = '姿態異常禁止啟動';
      notifyListeners();
      return false;
    }

    starting = true;
    error = null;
    statusMessage = '正在連線並啟動導航…';
    notifyListeners();

    try {
      if (ble.isConnected) {
        await ble.disconnect();
      }
      final speedFactor = settings.slopeSlowdown
          ? tilt.recommendedSpeedFactor
          : 1.0;
      final ok = await control.startDrive(
        instruction: instructionOverride ?? settings.instruction,
        ignoreRadar: ignoreRadar,
        speedFactor: speedFactor,
      );
      starting = false;
      running = ok;
      if (ok) {
        error = null;
        statusMessage = '自動導航進行中';
      } else {
        error = control.error ?? '自動導航啟動失敗（伺服器或車載端未回應）';
        statusMessage = '啟動失敗';
      }
      notifyListeners();
      return ok;
    } catch (e) {
      starting = false;
      running = false;
      error = '啟動導航錯誤：$e';
      statusMessage = '啟動失敗';
      notifyListeners();
      return false;
    }
  }

  Future<void> stop({String? reason}) async {
    pendingInstruction = null;
    final wasActive = running || starting;
    starting = false;
    running = false;
    statusMessage = reason ?? (control.connected ? '已停止（待機）' : '未連接導航通道');
    notifyListeners();
    if (wasActive || control.driving) {
      try {
        await control.stopDrive();
      } catch (e) {
        error = '停止指令傳送異常：$e';
        notifyListeners();
      }
    }
  }

  /// Hardened Dual-Path Emergency Stop:
  /// 1) Sends immediate stop over WebSocket to Jetson.
  /// 2) Sends immediate BLE `ONF + ONE` if phone BLE is connected.
  /// 3) If network control is disconnected during an emergency, attempts direct
  ///    BLE reconnect + emergency stop to override runaway motion locally!
  Future<void> emergencyStopAll({String reason = '緊急停止'}) async {
    pendingInstruction = null;
    starting = false;
    running = false;
    statusMessage = reason;
    notifyListeners();

    unawaited(control.stopDrive());
    if (ble.isConnected) {
      await ble.emergencyStop();
    } else if (!control.connected) {
      unawaited(() async {
        final ok = await ble.connectFirst(nameFilter: settings.bleName);
        if (ok) await ble.emergencyStop();
      }());
    }
  }

  void _onControl() {
    final driving = control.driving;
    if (running != driving) {
      running = driving;
    }
    if (control.error != null) {
      error = control.error;
      statusMessage = '連線異常';
    } else if (driving) {
      error = null;
      statusMessage = tilt.isOnSlope ? '自動導航中（斜坡慢行保護）' : '自動導航進行中';
    } else if (control.connected) {
      statusMessage = '車載導航已連線（待機）';
    } else {
      statusMessage = '未連接導航通道';
    }
    notifyListeners();
  }

  void _onRadar() {
    notifyListeners();
  }

  @override
  void dispose() {
    control.removeListener(_onControl);
    radar.removeListener(_onRadar);
    super.dispose();
  }
}
