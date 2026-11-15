import 'dart:math' as math;

/// Geometry derived from the level calibration reference.
class TiltGeometry {
  const TiltGeometry({
    required this.total,
    required this.frontBack,
    required this.leftRight,
  });

  /// Total angle away from the calibrated level pose, in degrees.
  final double total;

  /// Positive means the front is lower; negative means the back is lower.
  final double frontBack;

  /// Positive means the right side is lower; negative means the left side is lower.
  final double leftRight;

  // Match TiltMonitorActivity: suppress sub-degree noise below 1°.
  double get frontLower => frontBack > 1.0 ? frontBack : 0;
  double get backLower => frontBack < -1.0 ? -frontBack : 0;
  double get rightLower => leftRight > 1.0 ? leftRight : 0;
  double get leftLower => leftRight < -1.0 ? -leftRight : 0;
}

double dot3(List<double> a, List<double> b) =>
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

/// Normalizes a 3-vector, returning null for a zero / non-finite vector.
List<double>? normalize3(List<double> v) {
  final norm = math.sqrt(dot3(v, v));
  if (!norm.isFinite || norm < 1e-9) return null;
  return [v[0] / norm, v[1] / norm, v[2] / norm];
}

/// Converts the device-frame world-up vector into the current screen frame.
///
/// Android rotation constants are 0, 1, 2, 3 for 0°, 90°, 180° and 270°.
/// This mirrors TiltMonitorActivity's screen-rotation mapping exactly.
List<double>? screenUpVector(double x, double y, double z, int screenRotation) {
  final norm = math.sqrt(x * x + y * y + z * z);
  if (!norm.isFinite || norm < 0.9) return null;
  final nx = x / norm;
  final ny = y / norm;
  final nz = z / norm;
  switch (screenRotation) {
    case 1:
      return [ny, -nx, nz];
    case 2:
      return [-nx, -ny, nz];
    case 3:
      return [-ny, nx, nz];
    default:
      return [nx, ny, nz];
  }
}

/// Computes total tilt and the four-way decomposition relative to [reference].
///
/// [reference] is the calibrated world-up vector in the same screen frame.
/// The wheelchair frame is derived from screen-right and the level reference,
/// matching TiltMonitorActivity.
TiltGeometry? computeTilt(List<double> up, List<double> reference) {
  final u = normalize3(reference);
  final g = normalize3(up);
  if (u == null || g == null) return null;

  final dot = dot3(g, u).clamp(-1.0, 1.0);
  final total = math.acos(dot) * 180 / math.pi;

  final rightBase = <double>[1.0 - u[0] * u[0], -u[0] * u[1], -u[0] * u[2]];
  final right = normalize3(rightBase);
  if (right == null) return null;

  final front = <double>[
    u[1] * right[2] - u[2] * right[1],
    u[2] * right[0] - u[0] * right[2],
    u[0] * right[1] - u[1] * right[0],
  ];

  final vertical = dot3(g, u);
  final frontBack = math.atan2(-dot3(g, front), vertical) * 180 / math.pi;
  final leftRight = math.atan2(-dot3(g, right), vertical) * 180 / math.pi;

  return TiltGeometry(total: total, frontBack: frontBack, leftRight: leftRight);
}
