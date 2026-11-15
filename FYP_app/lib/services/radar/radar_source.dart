import '../../models/radar_models.dart';

/// Abstract radar input.
abstract class RadarSource {
  String get label;

  /// Whether this source can run on the current platform.
  bool get isSupported;

  Stream<RadarScan> get scans;

  Future<void> start();

  Future<void> stop();
}
