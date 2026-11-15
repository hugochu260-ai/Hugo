import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/services/tilt/tilt_analyzer.dart';

void main() {
  List<double> pose({double pitchDeg = 0, double rollDeg = 0}) {
    final p = pitchDeg * math.pi / 180.0;
    final r = rollDeg * math.pi / 180.0;
    // Upright screen baseline: y ~ cos, z ~ -sin(pitch), x ~ sin(roll)
    return [
      math.sin(r),
      math.cos(p) * math.cos(r),
      -math.sin(p) * math.cos(r),
    ];
  }

  test('steady 10-degree ramp enters slope slow-down WITHOUT false danger alarm', () {
    final a = TiltAnalyzer()..begin();
    final level = pose();
    a.update(x: level[0], y: level[1], z: level[2], screenRotation: 0, accuracy: 3, nowMs: 100);
    expect(a.calibrate(120), CalibrationOutcome.success);

    // 10-degree forward pitch (downhill ramp), small lateral roll, calm gyro
    final ramp = pose(pitchDeg: 10, rollDeg: 1.0);
    final alert1 = a.update(
      x: ramp[0], y: ramp[1], z: ramp[2],
      screenRotation: 0, accuracy: 3, nowMs: 500, gyroDegPerSec: 8.0, impactG: 0.05,
    );
    final alert2 = a.update(
      x: ramp[0], y: ramp[1], z: ramp[2],
      screenRotation: 0, accuracy: 3, nowMs: 1800, gyroDegPerSec: 5.0, impactG: 0.04,
    );

    expect(alert1, isNull);
    expect(alert2, isNull);
    expect(a.isOnSlope, isTrue);
    expect(a.isEmergency, isFalse);
    expect(a.recommendedSpeedFactor, lessThan(0.65));
    expect(a.recommendedSpeedFactor, greaterThan(0.35));
  });

  test('sudden impact spike + post-impact tilt triggers immediate fallDetected alarm', () {
    final a = TiltAnalyzer()..begin();
    final level = pose();
    a.update(x: level[0], y: level[1], z: level[2], screenRotation: 0, accuracy: 3, nowMs: 100);
    expect(a.calibrate(120), CalibrationOutcome.success);

    final fallen = pose(pitchDeg: 8, rollDeg: 15);
    final alert = a.update(
      x: fallen[0], y: fallen[1], z: fallen[2],
      screenRotation: 0, accuracy: 3, nowMs: 400, gyroDegPerSec: 145.0, impactG: 1.85,
    );

    expect(alert, isNotNull);
    expect(alert!.danger, isTrue);
    expect(alert.fallImpact, isTrue);
    expect(a.status, TiltStatus.fallDetected);
    expect(a.recommendedSpeedFactor, 0.0);
  });
}
