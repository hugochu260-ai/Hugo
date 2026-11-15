import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/drive_models.dart';
import '../settings_store.dart';

/// Communicates with Jetson control daemon over CT105 WebSocket (`/control`).
/// Reports 100% REAL telemetry and immediate connection errors — never fake data.
class JetsonControlService extends ChangeNotifier {
  JetsonControlService({required this.settings});

  final SettingsStore settings;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _waitTimeout;
  Timer? _heartbeat;
  bool _starting = false;
  bool _disposed = false;
  Completer<bool>? _wait;
  bool _waitTarget = false;

  bool connected = false;
  bool connecting = false;
  bool driving = false;
  String? error;
  DateTime? lastStatusAt;

  // Real telemetry reported by Jetson drive-loop (null when not reported)
  DriveDecision? realDecision;
  double? realJetsonFps;
  String speedMode = 'normal';

  String get controlUrl {
    final camera = Uri.tryParse(settings.cameraWsUrl.trim());
    if (camera != null && camera.host.isNotEmpty) {
      return camera.replace(path: '/control').toString();
    }
    return 'wss://radar.pikachumike.win/control';
  }

  Future<void> start() async {
    if (_disposed || _starting || _socket != null) return;
    _starting = true;
    connecting = true;
    notifyListeners();
    try {
      final socket = await WebSocket.connect(controlUrl)
          .timeout(const Duration(seconds: 8));
      if (_disposed) {
        await socket.close();
        return;
      }
      _socket = socket;
      connected = true;
      connecting = false;
      error = null;
      notifyListeners();
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
        if (connected) _send({'action': 'ping'});
      });
      _sub = socket.listen(
        _onMessage,
        onError: (Object e) => _closed('連線錯誤：$e'),
        onDone: () => _closed('控制通道已斷線'),
        cancelOnError: true,
      );
    } catch (e) {
      connecting = false;
      connected = false;
      realDecision = null;
      realJetsonFps = null;
      error = '無法連接導航控制通道（$controlUrl）：$e';
      notifyListeners();
      _scheduleRetry();
    } finally {
      _starting = false;
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    try {
      final json = jsonDecode(data);
      if (json is! Map) return;
      final map = json.cast<String, dynamic>();

      if (map['error'] is String && (map['error'] as String).isNotEmpty) {
        final err = map['error'] as String;
        error = err == 'agent_offline'
            ? '車載控制代理離線（Jetson 未連線）'
            : '控制通道回報錯誤：$err';
        if (err == 'agent_offline') {
          driving = false;
          realDecision = null;
          realJetsonFps = null;
        }
        notifyListeners();
        return;
      }

      if (map['type'] != 'status' && !map.containsKey('driving')) return;
      lastStatusAt = DateTime.now();
      final wasDriving = driving;
      driving = map['driving'] == true;
      error = null;

      if (map['fps'] is num) {
        realJetsonFps = (map['fps'] as num).toDouble();
      } else if (!driving) {
        realJetsonFps = null;
      }

      if (map['decision'] is Map) {
        realDecision = DriveDecision.fromJson(
          (map['decision'] as Map).cast<String, dynamic>(),
        );
      } else if (map['command'] is String) {
        realDecision = DriveDecision.fromJson(map);
      } else if (!driving) {
        realDecision = null;
      }

      if (driving != wasDriving || realDecision != null) {
        notifyListeners();
      }
      final wait = _wait;
      if (wait != null && !wait.isCompleted && driving == _waitTarget) {
        _waitTimeout?.cancel();
        wait.complete(true);
      }
    } catch (_) {}
  }

  Future<bool> startDrive({
    String? instruction,
    bool ignoreRadar = false,
    double speedFactor = 1.0,
  }) async {
    if (!connected) await start();
    if (_socket == null || !connected) {
      error ??= '未連接導航控制通道，無法啟動自動導航';
      notifyListeners();
      return false;
    }
    final future = _waitFor(true, const Duration(seconds: 12));
    _send({
      'action': 'start',
      'instruction': (instruction ?? settings.instruction).trim(),
      'ignore_radar': ignoreRadar,
      'speed_factor': speedFactor,
    });
    final ok = await future;
    if (!ok) {
      error ??= '車載導航未回應啟動（請確認 Jetson 在線且電源正常）';
      notifyListeners();
    }
    return ok;
  }

  void updateSpeedFactor(double factor, {required bool onSlope}) {
    final nextMode = onSlope ? 'slow_slope' : 'normal';
    if (speedMode == nextMode && !driving) return;
    speedMode = nextMode;
    if (connected) {
      _send({
        'action': 'speed',
        'mode': nextMode,
        'speed_factor': factor,
      });
    }
  }

  Future<void> setCameraMode(String mode) async {
    if (!connected) await start();
    if (_socket == null) return;
    _send({'action': 'camera_mode', 'mode': mode});
  }

  Future<void> stopDrive() async {
    if (_socket == null) return;
    final future = _waitFor(false, const Duration(seconds: 5));
    _send({'action': 'stop'});
    await future;
  }

  Future<bool> _waitFor(bool target, Duration timeout) {
    _waitTimeout?.cancel();
    if (_wait != null && !_wait!.isCompleted) {
      _wait!.complete(false);
    }
    _waitTarget = target;
    final completer = Completer<bool>();
    _wait = completer;
    if (driving == target && error == null) {
      completer.complete(true);
      return completer.future;
    }
    _waitTimeout = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    return completer.future;
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _socket?.add(jsonEncode(payload));
    } catch (e) {
      _closed('傳送指令失敗：$e');
    }
  }

  void _closed(String reason) {
    if (_disposed) return;
    connected = false;
    connecting = false;
    driving = false;
    realDecision = null;
    realJetsonFps = null;
    _socket = null;
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    error = reason;
    if (_wait != null && !_wait!.isCompleted) {
      _wait!.complete(false);
    }
    notifyListeners();
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), () {
      if (!_disposed) unawaited(start());
    });
  }

  Future<void> stop() async {
    _retry?.cancel();
    _heartbeat?.cancel();
    _waitTimeout?.cancel();
    await _sub?.cancel();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    connected = false;
    connecting = false;
    realDecision = null;
    realJetsonFps = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _heartbeat?.cancel();
    _waitTimeout?.cancel();
    _sub?.cancel();
    _socket?.close();
    super.dispose();
  }
}
