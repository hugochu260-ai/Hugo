import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// One STL-27L return in polar coordinates.
class RadarPoint {
  const RadarPoint({
    required this.angleDeg,
    required this.rangeM,
    this.intensity = 0,
  });

  final double angleDeg;
  final double rangeM;
  final int intensity;

  double get x => rangeM * math.sin(angleDeg * math.pi / 180.0);
  double get y => rangeM * math.cos(angleDeg * math.pi / 180.0);

  @override
  String toString() =>
      'RadarPoint(angle: ${angleDeg.toStringAsFixed(1)}, range: '
      '${rangeM.toStringAsFixed(2)})';
}

/// One complete 360° revolution.
class RadarScan {
  RadarScan({required this.points, DateTime? at}) : at = at ?? DateTime.now();

  final List<RadarPoint> points;
  final DateTime at;

  bool get isEmpty => points.isEmpty;
  int get length => points.length;

  double? nearestInSector(
    double centerDeg, {
    double halfWidthDeg = 35.0,
    double minRangeM = 0.20,
    double maxRangeM = 25.0,
    double clusterToleranceM = 0.15,
  }) {
    final values = <double>[];
    for (final p in points) {
      if (p.rangeM < minRangeM || p.rangeM > maxRangeM) continue;
      var delta = (p.angleDeg - centerDeg) % 360.0;
      if (delta > 180.0) delta -= 360.0;
      if (delta < -180.0) delta += 360.0;
      if (delta.abs() <= halfWidthDeg) values.add(p.rangeM);
    }
    if (values.length < 3) return null;
    values.sort();
    for (var i = 0; i + 2 < values.length; i++) {
      if (values[i + 2] - values[i] <= clusterToleranceM) {
        return values[i];
      }
    }
    return values.first;
  }

  double? get frontM => nearestInSector(0, minRangeM: 0.60);
  double? get rearM => nearestInSector(180, minRangeM: 0.60);

  /// Compact binary scan encoding (u16 count + angle/range pairs).
  static String? encodeScan(RadarScan scan) {
    const maxPoints = 900;
    final n = scan.points.length;
    if (n == 0) return null;
    final step = (n / maxPoints).ceil().clamp(1, 100000);
    final bytes = BytesBuilder(copy: false);
    var count = 0;
    final data = <int>[];
    for (var i = 0; i < n && count < maxPoints; i += step) {
      final p = scan.points[i];
      if (p.rangeM < 0.05 || p.rangeM > 25.0) continue;
      final angle = (p.angleDeg * 100).round() % 36000;
      final range = (p.rangeM * 1000).round().clamp(0, 65535);
      data
        ..add(angle & 0xFF)
        ..add((angle >> 8) & 0xFF)
        ..add(range & 0xFF)
        ..add((range >> 8) & 0xFF);
      count++;
    }
    if (count < 4) return null;
    bytes
      ..add([count & 0xFF, (count >> 8) & 0xFF])
      ..add(data);
    return base64Encode(bytes.toBytes());
  }
}

enum RadarConnectionState { disconnected, connecting, connected, error }

class RadarStatus {
  const RadarStatus({
    this.state = RadarConnectionState.disconnected,
    this.sourceLabel = '未連接',
    this.scan,
    this.error,
    this.hz = 0,
  });

  final RadarConnectionState state;
  final String sourceLabel;
  final RadarScan? scan;
  final String? error;
  final double hz;

  bool get connected => state == RadarConnectionState.connected;
  bool get hasFreshScan =>
      scan != null && DateTime.now().difference(scan!.at).inMilliseconds < 1500;

  double? get frontM => scan?.frontM;
  double? get rearM => scan?.rearM;

  RadarStatus copyWith({
    RadarConnectionState? state,
    String? sourceLabel,
    RadarScan? scan,
    String? error,
    double? hz,
  }) =>
      RadarStatus(
        state: state ?? this.state,
        sourceLabel: sourceLabel ?? this.sourceLabel,
        scan: scan ?? this.scan,
        error: error ?? this.error,
        hz: hz ?? this.hz,
      );
}
