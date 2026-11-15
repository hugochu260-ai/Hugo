import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/services/eye/gaze_calibration.dart';
import 'package:fyp_app/services/eye/gaze_features.dart';

void main() {
  test('rejectCalibrationOutliers removes a bad calibration frame', () {
    final good = List.generate(
      12,
      (_) => CalibrationSample(
        features: List<double>.filled(GazeFeatures.size, 1.0),
        target: const Offset(0.5, 0.5),
      ),
    );
    final bad = CalibrationSample(
      features: List<double>.filled(GazeFeatures.size, 100.0),
      target: const Offset(0.5, 0.5),
    );

    final kept = rejectCalibrationOutliers([...good, bad]);

    expect(kept.length, good.length);
    expect(kept.every((s) => s.features[0] == 1.0), isTrue);
  });
}
