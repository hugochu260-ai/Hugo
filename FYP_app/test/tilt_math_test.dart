import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/services/tilt/tilt_math.dart';

void main() {
  group('screenUpVector', () {
    test('maps all Android screen rotations', () {
      const x = 0.2;
      const y = 0.9;
      const z = 0.3;
      final norm = math.sqrt(x * x + y * y + z * z);

      expect(
        screenUpVector(x, y, z, 0),
        orderedEquals([x / norm, y / norm, z / norm]),
      );
      expect(
        screenUpVector(x, y, z, 1),
        orderedEquals([y / norm, -x / norm, z / norm]),
      );
      expect(
        screenUpVector(x, y, z, 2),
        orderedEquals([-x / norm, -y / norm, z / norm]),
      );
      expect(
        screenUpVector(x, y, z, 3),
        orderedEquals([-y / norm, x / norm, z / norm]),
      );
    });

    test('rejects an unreliable rotation vector', () {
      expect(screenUpVector(0.1, 0.1, 0.1, 0), isNull);
    });
  });

  group('computeTilt', () {
    const reference = [0.0, 1.0, 0.0];

    test('level pose produces zero tilt', () {
      final result = computeTilt(reference, reference)!;
      expect(result.total, closeTo(0, 1e-9));
      expect(result.frontBack, closeTo(0, 1e-9));
      expect(result.leftRight, closeTo(0, 1e-9));
    });

    test('10 degree forward pitch reports the front as lower', () {
      final a = 10 * math.pi / 180;
      final up = [0.0, math.cos(a), math.sin(a)];
      final result = computeTilt(up, reference)!;
      expect(result.total, closeTo(10, 1e-6));
      expect(result.frontBack, closeTo(10, 1e-6));
      expect(result.leftRight, closeTo(0, 1e-6));
      expect(result.frontLower, closeTo(10, 1e-6));
      expect(result.backLower, 0);
    });

    test('10 degree right roll reports the right as lower', () {
      final a = 10 * math.pi / 180;
      final up = [-math.sin(a), math.cos(a), 0.0];
      final result = computeTilt(up, reference)!;
      expect(result.total, closeTo(10, 1e-6));
      expect(result.leftRight, closeTo(10, 1e-6));
      expect(result.frontBack, closeTo(0, 1e-6));
      expect(result.rightLower, closeTo(10, 1e-6));
      expect(result.leftLower, 0);
    });

    test('backwards pitch reports the back as lower', () {
      final a = 6 * math.pi / 180;
      final up = [0.0, math.cos(a), -math.sin(a)];
      final result = computeTilt(up, reference)!;
      expect(result.frontBack, closeTo(-6, 1e-6));
      expect(result.backLower, closeTo(6, 1e-6));
      expect(result.frontLower, 0);
    });
  });
}
