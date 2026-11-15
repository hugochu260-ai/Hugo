import 'tilt_math.dart';

/// Enhanced Wheelchair / Test-Vehicle Posture States:
/// Distinguishes normal accessible slope climbing/descending (`slopeUp` /
/// `slopeDown` -> automatic slow-down, NO false fall alarm!) from dangerous
/// lateral rollover (`danger`) or sudden fall impact (`fallDetected`).
enum TiltStatus {
  idle,
  waiting,
  unsupported,
  uncalibrated,
  monitoring,
  slopeUp,
  slopeDown,
  warning,
  danger,
  fallDetected,
  stale,
  orientationChanged,
  sensorUnreliable,
  calibrationNoData,
  calibrationPosture,
  startFailed,
}

enum CalibrationOutcome { success, noData, posture }

class TiltAlert {
  const TiltAlert({
    required this.danger,
    this.fallImpact = false,
  });

  final bool danger;
  final bool fallImpact;
}

class TiltAnalyzer {
  static const double slopeEnterDegrees = 6.0;
  static const double slopeMaxSafeDegrees = 15.5;
  static const double lateralWarningDegrees = 8.5;
  static const double lateralDangerDegrees = 12.5;
  static const double extremeTotalDegrees = 21.0;

  static const double fallGyroDegPerSec = 105.0;
  static const double fallImpactG = 1.50;
  static const double postImpactTiltDegrees = 13.5;

  static const double warningDegrees = 8.5;
  static const double dangerDegrees = 12.5;
  static const int holdMs = 900;
  static const int staleMs = 2500;
  static const int alertRepeatMs = 2500;
  static const int messageHoldMs = 4000;
  static const int sensorStatusUnreliable = -1;

  TiltStatus _status = TiltStatus.idle;
  TiltGeometry? _reading;
  List<double>? _current;
  List<double>? _reference;
  int? _baselineRotation;
  int? _lastRotation;
  int? _lastSampleAtMs;
  int _overWarningAtMs = 0;
  int _overDangerAtMs = 0;
  int _lastSpikeAtMs = 0;
  int _lastAlertAtMs = 0;
  int _statusHoldUntilMs = 0;
  bool _canCalibrate = false;

  double latestGyroDegPerSec = 0;
  double latestImpactG = 0;

  TiltStatus get status => _status;
  TiltGeometry? get reading => _reading;
  bool get canCalibrate => _canCalibrate;
  bool get isCalibrated => _reference != null;
  int? get screenRotation => _lastRotation;
  int? get lastSampleAtMs => _lastSampleAtMs;

  bool get isOnSlope =>
      _status == TiltStatus.slopeUp || _status == TiltStatus.slopeDown;

  bool get isEmergency =>
      _status == TiltStatus.danger || _status == TiltStatus.fallDetected;

  double get recommendedSpeedFactor {
    switch (_status) {
      case TiltStatus.danger:
      case TiltStatus.fallDetected:
        return 0.0;
      case TiltStatus.warning:
        return 0.40;
      case TiltStatus.slopeDown:
        return 0.48;
      case TiltStatus.slopeUp:
        return 0.58;
      default:
        return 1.0;
    }
  }

  void begin() {
    _status = TiltStatus.waiting;
    _reading = null;
    _current = null;
    _reference = null;
    _baselineRotation = null;
    _lastRotation = null;
    _lastSampleAtMs = null;
    _overWarningAtMs = 0;
    _overDangerAtMs = 0;
    _lastSpikeAtMs = 0;
    _lastAlertAtMs = 0;
    _statusHoldUntilMs = 0;
    _canCalibrate = false;
  }

  void reset() {
    begin();
    _status = TiltStatus.idle;
  }

  void markUnsupported() {
    _status = TiltStatus.unsupported;
    _reading = null;
    _current = null;
    _reference = null;
    _baselineRotation = null;
    _canCalibrate = false;
  }

  void markStartFailed() {
    _status = TiltStatus.startFailed;
    _reading = null;
    _current = null;
    _reference = null;
    _baselineRotation = null;
    _canCalibrate = false;
  }

  void setAccuracy(int accuracy, int nowMs) {
    if (accuracy != sensorStatusUnreliable) return;
    if (_status == TiltStatus.idle ||
        _status == TiltStatus.unsupported ||
        _status == TiltStatus.sensorUnreliable) {
      return;
    }
    _clearCalibration();
    _canCalibrate = false;
    _status = TiltStatus.sensorUnreliable;
    _statusHoldUntilMs = 0;
  }

  TiltAlert? update({
    required double x,
    required double y,
    required double z,
    required int screenRotation,
    required int accuracy,
    required int nowMs,
    double gyroDegPerSec = 0.0,
    double impactG = 0.0,
  }) {
    final up = screenUpVector(x, y, z, screenRotation);
    if (up == null) return null;

    latestGyroDegPerSec = gyroDegPerSec;
    latestImpactG = impactG;

    final previousSample = _lastSampleAtMs;
    if (previousSample != null && nowMs - previousSample > staleMs) {
      _overWarningAtMs = 0;
      _overDangerAtMs = 0;
    }
    _lastSampleAtMs = nowMs;
    _lastRotation = screenRotation;
    _current = up;

    if (accuracy == sensorStatusUnreliable) {
      _clearCalibration();
      _canCalibrate = false;
      _status = TiltStatus.sensorUnreliable;
      _statusHoldUntilMs = 0;
      return null;
    }

    if (_baselineRotation != null && _baselineRotation != screenRotation) {
      _reference = null;
      _baselineRotation = null;
      _reading = null;
      _overWarningAtMs = 0;
      _overDangerAtMs = 0;
      _canCalibrate = true;
      _status = TiltStatus.orientationChanged;
      _statusHoldUntilMs = nowMs + messageHoldMs;
      return null;
    }

    _canCalibrate = true;
    final base = _reference;
    if (base == null) {
      if (nowMs >= _statusHoldUntilMs) {
        _status = TiltStatus.uncalibrated;
      }
      _reading = null;
      return null;
    }

    final geometry = computeTilt(up, base);
    if (geometry == null) return null;
    _reading = geometry;

    final total = geometry.total;
    final pitch = geometry.frontBack;
    final absPitch = pitch.abs();
    final absRoll = geometry.leftRight.abs();

    if (gyroDegPerSec >= fallGyroDegPerSec || impactG >= fallImpactG) {
      _lastSpikeAtMs = nowMs;
    }
    final recentSpike =
        _lastSpikeAtMs > 0 && (nowMs - _lastSpikeAtMs) <= 1800;

    if (recentSpike && total >= postImpactTiltDegrees) {
      _status = TiltStatus.fallDetected;
      if (_lastAlertAtMs == 0 || nowMs - _lastAlertAtMs >= alertRepeatMs) {
        _lastAlertAtMs = nowMs;
        return const TiltAlert(danger: true, fallImpact: true);
      }
      return null;
    }

    final isDangerCondition =
        absRoll >= lateralDangerDegrees || total >= extremeTotalDegrees;
    final isWarningCondition =
        absRoll >= lateralWarningDegrees || absPitch > slopeMaxSafeDegrees;
    final isSteadySlope = !isDangerCondition &&
        !isWarningCondition &&
        absPitch >= slopeEnterDegrees &&
        gyroDegPerSec < 65.0;

    if (isDangerCondition) {
      if (_overDangerAtMs == 0) _overDangerAtMs = nowMs;
    } else {
      _overDangerAtMs = 0;
    }

    if (isWarningCondition || isDangerCondition) {
      if (_overWarningAtMs == 0) _overWarningAtMs = nowMs;
    } else {
      _overWarningAtMs = 0;
    }

    final dangerActive =
        _overDangerAtMs != 0 && nowMs - _overDangerAtMs >= holdMs;
    final warningActive =
        _overWarningAtMs != 0 && nowMs - _overWarningAtMs >= holdMs;

    if (dangerActive) {
      _status = TiltStatus.danger;
    } else if (warningActive) {
      _status = TiltStatus.warning;
    } else if (isSteadySlope) {
      _status = pitch > 0 ? TiltStatus.slopeDown : TiltStatus.slopeUp;
    } else {
      _status = TiltStatus.monitoring;
    }

    if ((dangerActive || warningActive) &&
        (_lastAlertAtMs == 0 || nowMs - _lastAlertAtMs >= alertRepeatMs)) {
      _lastAlertAtMs = nowMs;
      return TiltAlert(danger: dangerActive);
    }
    return null;
  }

  void watchdog(int nowMs) {
    if (_status == TiltStatus.idle || _status == TiltStatus.unsupported) return;
    final last = _lastSampleAtMs;
    if (last != null && nowMs - last <= staleMs) return;

    _reading = null;
    _canCalibrate = false;
    _status = TiltStatus.stale;
    _statusHoldUntilMs = 0;
  }

  /// Supports calibrating at ANY angled phone holder (upright 90°, angled 45°
  /// facing the wheelchair rider, or flat 0° on the car roof) as long as the
  /// phone isn't tilted sharply sideways (`sample[0].abs() <= 0.45`)!
  CalibrationOutcome calibrate(int nowMs, {bool relaxPosture = false}) {
    final sample = _current;
    final last = _lastSampleAtMs;
    if (_status == TiltStatus.sensorUnreliable ||
        sample == null ||
        last == null ||
        nowMs - last > staleMs) {
      _status = TiltStatus.calibrationNoData;
      _statusHoldUntilMs = nowMs + messageHoldMs;
      return CalibrationOutcome.noData;
    }

    if (relaxPosture) {
      if (sample[0].abs() > 0.48) {
        _status = TiltStatus.calibrationPosture;
        _statusHoldUntilMs = nowMs + messageHoldMs;
        return CalibrationOutcome.posture;
      }
    } else {
      final uprightOk = sample[1] >= 0.45 && sample[0].abs() <= 0.38;
      final flatMountOk = sample[2].abs() >= 0.55 && sample[0].abs() <= 0.38;
      if (!uprightOk && !flatMountOk) {
        _status = TiltStatus.calibrationPosture;
        _statusHoldUntilMs = nowMs + messageHoldMs;
        return CalibrationOutcome.posture;
      }
    }

    _reference = List<double>.of(sample);
    _baselineRotation = _lastRotation;
    _overWarningAtMs = 0;
    _overDangerAtMs = 0;
    _lastSpikeAtMs = 0;
    _lastAlertAtMs = 0;
    _statusHoldUntilMs = 0;
    _status = TiltStatus.monitoring;
    _reading = computeTilt(sample, _reference!) ??
        const TiltGeometry(total: 0, frontBack: 0, leftRight: 0);
    return CalibrationOutcome.success;
  }

  void _clearCalibration() {
    _reference = null;
    _reading = null;
    _current = null;
    _overWarningAtMs = 0;
    _overDangerAtMs = 0;
  }
}
