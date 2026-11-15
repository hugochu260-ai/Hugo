import 'dart:ui';

/// A single MediaPipe face result, reduced to what the gaze pipeline needs.
class FaceObservation {
  const FaceObservation({
    required this.landmarks,
    required this.imageWidth,
    required this.imageHeight,
    required this.blinkLeft,
    required this.blinkRight,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.score,
  });

  /// 478 normalised landmarks (x, y in 0..1).
  final List<Offset> landmarks;
  final int imageWidth;
  final int imageHeight;
  final double blinkLeft;
  final double blinkRight;
  final double yaw;
  final double pitch;
  final double roll;
  final double score;

  bool get isValid => landmarks.length >= 478;

  double get eyeMidX => (landmarks[468].dx + landmarks[473].dx) / 2.0;
  double get eyeMidY => (landmarks[468].dy + landmarks[473].dy) / 2.0;
}
