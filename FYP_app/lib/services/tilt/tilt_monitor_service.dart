import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tilt_analyzer.dart';
import 'tilt_math.dart';

/// Smart Scene-Aware Posture, Slope & Fall Monitor (v3.5):
/// Solves the real-world Handheld vs Wheelchair-Mounted paradox!
///
/// 1) `effectiveMountedMode == false` (Handheld / Daily Standalone Mode — default
///    whenever NO wheelchair/car is connected in `auto` mode, OR when `handheld` is selected):
///    - Picking up the phone from flat on a desk to upright viewing NEVER beeps!
///    - ONLY a genuine violent drop / fall impact (`impactG >= 1.85` & `gyro >= 130°/s`)
///      triggers an emergency fall alert!
/// 2) `effectiveMountedMode == true` (Wheelchair / Car Holder Mode — automatically
///    engages when BLE car / VLN navigation connects in `auto` mode, OR when `mounted` is selected):
///    - Automatically locks the current holder angle (whether upright facing the user
///      OR flat on the chassis!) once steady (`gyro < 12°/s` for 1.2s).
///    - Touch-to-Adjust Auto-Mute: When a human finger touches/operates the screen,
///      static tilt alarms pause for 4.5s, and once the phone rests steadily back
///      on the holder for 1.5s, it automatically re-zeros to the new mount angle!
class TiltMonitorService extends ChangeNotifier {
  TiltMonitorService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleCall);
  }

  static const String _channelName = 'fyp/tilt';

  final MethodChannel _channel;
  final TiltAnalyzer _analyzer = TiltAnalyzer();
  final Stopwatch _clock = Stopwatch()..start();

  Timer? _watchdog;
  bool _active = false;
  bool _supported = true;
  bool _disposed = false;
  int _lastNotifyAtMs = 0;

  // Smart context state
  String userTiltMode = 'auto'; // 'auto' | 'handheld' | 'mounted'
  bool hardwareConnected = false;
  int _lastUserTouchMs = -99999;
  bool _needsMountRelock = true;
  int _steadySinceMs = 0;

  String sensorName = '';
  String sensorType = '';

  void Function(TiltStatus status, bool fallImpact)? onEmergencyDanger;
  void Function(double speedFactor, bool onSlope)? onSpeedFactorChanged;
  double _lastReportedSpeed = 1.0;

  /// True when static wheelchair tilt & slope slow-down should be active.
  /// False when phone is in daily handheld use (only sudden high-G fall impacts alarm!).
  String get activeModeLabel => isMountedProtectionActive
      ? (isTouchAdjustingNow ? '車載支架（觸控調校靜音中）' : '車載支架保護模式')
      : '手持日常防跌模式（攞起睇 mon 唔會亂響）';

  bool get isMountedProtectionActive {
    if (userTiltMode == 'mounted') return true;
    if (userTiltMode == 'handheld') return false;
    return hardwareConnected; // 'auto': handheld until car/wheelchair links!
  }

  bool get isTouchAdjustingNow =>
      (_clock.elapsedMilliseconds - _lastUserTouchMs) < 4500;

  TiltStatus get status =>
      isMountedProtectionActive ? _analyzer.status : TiltStatus.monitoring;
  TiltGeometry? get reading => _analyzer.reading;
  bool get canCalibrate => _analyzer.canCalibrate;
  bool get isCalibrated => _analyzer.isCalibrated;
  bool get isSupported => _supported;
  bool get isActive => _active;
  bool get isOnSlope => isMountedProtectionActive && _analyzer.isOnSlope;
  bool get isEmergency => _analyzer.isEmergency;
  double get recommendedSpeedFactor =>
      isMountedProtectionActive ? _analyzer.recommendedSpeedFactor : 1.0;
  double get gyroDegPerSec => _analyzer.latestGyroDegPerSec;
  double get impactG => _analyzer.latestImpactG;
  int? get screenRotation => _analyzer.screenRotation;

  bool get isFresh {
    final last = _analyzer.lastSampleAtMs;
    if (last == null) return false;
    return _clock.elapsedMilliseconds - last <= TiltAnalyzer.staleMs;
  }

  /// Called by top-level Listener whenever user touches/scrolls the screen so
  /// holding the phone to adjust settings NEVER triggers annoying tilt beeps!
  void recordUserTouch() {
    _lastUserTouchMs = _clock.elapsedMilliseconds;
    // If mounted on car and user picked it up to adjust, re-lock once placed back still!
    if (isMountedProtectionActive && _analyzer.latestGyroDegPerSec > 18.0) {
      _needsMountRelock = true;
      _steadySinceMs = 0;
    }
  }

  void syncContext({required String mode, required bool isHardwareLinked}) {
    final prevMounted = isMountedProtectionActive;
    userTiltMode = mode;
    hardwareConnected = isHardwareLinked;
    final nowMounted = isMountedProtectionActive;
    if (!prevMounted && nowMounted) {
      // Just switched into mounted mode (e.g. car just connected!) -> lock current holder angle!
      _needsMountRelock = true;
      _steadySinceMs = 0;
    }
    _notify(force: true);
  }

  Future<void> start() async {
    if (_disposed || _active) return;
    _active = true;
    _supported = true;
    _analyzer.begin();
    _lastNotifyAtMs = 0;
    notifyListeners();

    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('start')
          .timeout(const Duration(seconds: 3));
      if (_disposed || !_active) {
        unawaited(_channel.invokeMethod<void>('stop'));
        return;
      }
      if (result == null || result['supported'] != true) {
        _supported = false;
        _analyzer.markUnsupported();
      } else {
        sensorName = result['sensor'] as String? ?? '';
        sensorType = result['type'] as String? ?? '';
      }
    } on MissingPluginException {
      _supported = false;
      _analyzer.markUnsupported();
    } on PlatformException {
      _supported = false;
      _analyzer.markUnsupported();
    } on TimeoutException {
      _supported = false;
      _analyzer.markStartFailed();
    }

    if (!_supported) {
      _watchdog?.cancel();
      _watchdog = null;
      notifyListeners();
      return;
    }

    _watchdog ??= Timer.periodic(const Duration(milliseconds: 600), (_) {
      final before = _analyzer.status;
      _analyzer.watchdog(_clock.elapsedMilliseconds);
      if (_analyzer.status != before) {
        _notify(force: true);
      }
    });
    notifyListeners();
  }

  Future<void> stop() async {
    final wasActive = _active;
    _active = false;
    _watchdog?.cancel();
    _watchdog = null;
    if (wasActive) {
      try {
        await _channel
            .invokeMethod<void>('stop')
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
    }
    _analyzer.reset();
    sensorName = '';
    sensorType = '';
    _notify(force: true);
  }

  CalibrationOutcome calibrate() {
    final outcome = _analyzer.calibrate(_clock.elapsedMilliseconds, relaxPosture: true);
    if (outcome == CalibrationOutcome.success) {
      _needsMountRelock = false;
      _steadySinceMs = 0;
    }
    _notify(force: true);
    return outcome;
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (!_active || _disposed) return null;
    if (call.method == 'sample') {
      final args = call.arguments;
      if (args is! Map) return null;
      final x = (args['x'] as num?)?.toDouble();
      final y = (args['y'] as num?)?.toDouble();
      final z = (args['z'] as num?)?.toDouble();
      final rotation = (args['rotation'] as num?)?.toInt();
      final accuracy = (args['accuracy'] as num?)?.toInt() ?? 0;
      final gyro = (args['gyroDegPerSec'] as num?)?.toDouble() ?? 0.0;
      final impact = (args['impactG'] as num?)?.toDouble() ?? 0.0;
      if (x == null || y == null || z == null || rotation == null) return null;

      final nowMs = _clock.elapsedMilliseconds;
      final before = _analyzer.status;

      // Update underlying sensor math
      final rawAlert = _analyzer.update(
        x: x,
        y: y,
        z: z,
        screenRotation: rotation,
        accuracy: accuracy,
        nowMs: nowMs,
        gyroDegPerSec: gyro,
        impactG: impact,
      );

      // CASE 1: Daily Handheld Mode (no car connected in 'auto', or 'handheld' mode)
      // NEVER beep when picking up the phone upright or tilting to watch the screen!
      // ONLY alarm on a violent real-world drop/fall impact (impact >= 1.85G & gyro >= 130°/s).
      if (!isMountedProtectionActive) {
        if (impact >= 1.85 && gyro >= 130.0) {
          unawaited(_channel.invokeMethod<void>('playAlert', {'danger': true}));
          onEmergencyDanger?.call(TiltStatus.fallDetected, true);
        }
        if (_lastReportedSpeed != 1.0) {
          _lastReportedSpeed = 1.0;
          onSpeedFactorChanged?.call(1.0, false);
        }
        _notify(force: false);
        return null;
      }

      // CASE 2: Mounted Wheelchair / Car Mode!
      // If user's hand is actively touching the screen (adjusting settings), suppress
      // static tilt alarms and mark for auto-relock once placed back down steadily!
      if (isTouchAdjustingNow && impact < 1.45) {
        if (gyro > 16.0) {
          _needsMountRelock = true;
          _steadySinceMs = 0;
        }
        _notify(force: false);
        return null;
      }

      // Auto-lock mount baseline (works for BOTH upright screen-facing holders & flat mounts!)
      if ((_needsMountRelock || !_analyzer.isCalibrated) && _analyzer.canCalibrate) {
        if (gyro < 11.0 && impact < 0.35) {
          if (_steadySinceMs == 0) {
            _steadySinceMs = nowMs;
          } else if (nowMs - _steadySinceMs >= 1100) {
            final out = _analyzer.calibrate(nowMs, relaxPosture: true);
            if (out == CalibrationOutcome.success) {
              _needsMountRelock = false;
              _steadySinceMs = 0;
            }
          }
        } else {
          _steadySinceMs = 0;
        }
      }

      final speed = _analyzer.recommendedSpeedFactor;
      if ((speed - _lastReportedSpeed).abs() > 0.01) {
        _lastReportedSpeed = speed;
        onSpeedFactorChanged?.call(speed, _analyzer.isOnSlope);
      }

      if (rawAlert != null && !_needsMountRelock) {
        unawaited(
          _channel.invokeMethod<void>('playAlert', {'danger': rawAlert.danger}),
        );
        if (rawAlert.danger) {
          onEmergencyDanger?.call(_analyzer.status, rawAlert.fallImpact);
        }
      }
      _notify(force: _analyzer.status != before);
    } else if (call.method == 'accuracy') {
      final args = call.arguments;
      if (args is! Map) return null;
      final accuracy = (args['accuracy'] as num?)?.toInt();
      if (accuracy == null) return null;
      final before = _analyzer.status;
      _analyzer.setAccuracy(accuracy, _clock.elapsedMilliseconds);
      if (_analyzer.status != before) {
        _notify(force: true);
      }
    }
    return null;
  }

  void _notify({bool force = false}) {
    if (_disposed) return;
    final now = _clock.elapsedMilliseconds;
    if (!force && now - _lastNotifyAtMs < 65) return;
    _lastNotifyAtMs = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}
