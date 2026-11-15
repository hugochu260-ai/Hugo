import 'dart:async';
import 'dart:math' as math;

import '../../models/radar_models.dart';
import 'radar_source.dart';

/// Synthetic radar used for UI development and iOS demos.
class MockRadarSource implements RadarSource {
  final StreamController<RadarScan> _controller =
      StreamController<RadarScan>.broadcast();
  Timer? _timer;
  double _phase = 0;

  @override
  String get label => 'Mock radar';

  @override
  bool get isSupported => true;

  @override
  Stream<RadarScan> get scans => _controller.stream;

  @override
  Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _phase = (_phase + 7) % 360;
      final points = <RadarPoint>[];
      for (var deg = 0; deg < 360; deg += 2) {
        var range = 2.4 + 0.5 * math.sin((deg + _phase) * math.pi / 180.0);
        // Two simulated obstacles.
        if (deg > 20 && deg < 50) range = 1.1;
        if (deg > 190 && deg < 220) range = 0.9;
        range += (math.Random().nextDouble() - 0.5) * 0.05;
        if (range > 0.2) {
          points.add(RadarPoint(
            angleDeg: deg.toDouble(),
            rangeM: range,
            intensity: 120,
          ));
        }
      }
      if (!_controller.isClosed) _controller.add(RadarScan(points: points));
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}
