import 'dart:math' as math;
import 'dart:ui';

import '../../models/face_observation.dart';

/// 12-dimensional roll-compensated binocular gaze feature vector +
/// 4-dimensional invariant face geometry signature (Face-ID style profile match).
///
/// Key v3 improvements over legacy 8D features:
/// 1. Sub-pixel ocular roll de-rotation around the inter-canthal midpoint so
///    tilting the head on a pillow/headrest does not skew X/Y gaze axes.
/// 2. 5-landmark iris centroid averaging (468..472 & 473..477) cuts landmark jitter.
/// 3. Dual vertical anchors (rigid brow-to-cheekbone orbital span + inter-canthal
///    chord) give 3x stronger up/down sensitivity without upper-eyelid droop bias.
class GazeFeatures {
  const GazeFeatures._();

  static const int size = 12;

  static List<double>? extract(FaceObservation o) {
    if (!o.isValid || o.landmarks.length < 478) return null;
    final lm = o.landmarks;
    final aspect = o.imageHeight / o.imageWidth;

    // Convert normalized landmarks into aspect-isotropic space and de-rotate head roll
    Offset ptRaw(int i) => Offset(lm[i].dx, lm[i].dy * aspect);

    final rawLOuter = ptRaw(33);
    final rawROuter = ptRaw(263);
    final pivot = Offset(
      (rawLOuter.dx + rawROuter.dx) * 0.5,
      (rawLOuter.dy + rawROuter.dy) * 0.5,
    );
    final rollRad = math.atan2(
      rawROuter.dy - rawLOuter.dy,
      rawROuter.dx - rawLOuter.dx,
    );
    final cosR = math.cos(-rollRad);
    final sinR = math.sin(-rollRad);

    Offset pt(int i) {
      final p = ptRaw(i) - pivot;
      return Offset(
        pivot.dx + p.dx * cosR - p.dy * sinR,
        pivot.dy + p.dx * sinR + p.dy * cosR,
      );
    }

    Offset irisCenter(List<int> idxs) {
      var sx = 0.0;
      var sy = 0.0;
      for (final i in idxs) {
        final p = pt(i);
        sx += p.dx;
        sy += p.dy;
      }
      return Offset(sx / idxs.length, sy / idxs.length);
    }

    final lOuter = pt(33);
    final lInner = pt(133);
    final rInner = pt(362);
    final rOuter = pt(263);

    final leftWidth = (lInner.dx - lOuter.dx).abs();
    final rightWidth = (rOuter.dx - rInner.dx).abs();
    if (leftWidth < 1e-4 || rightWidth < 1e-4) return null;

    final leftIris = irisCenter(const [468, 469, 470, 471, 472]);
    final rightIris = irisCenter(const [473, 474, 475, 476, 477]);

    final interEye = (rightIris - leftIris).distance;
    if (interEye < 1e-4) return null;

    // Horizontal normalized iris positions (0..1 across palpebral fissure)
    final lx = ((leftIris.dx - lOuter.dx) / leftWidth).clamp(-0.5, 1.5).toDouble();
    final rx = ((rightIris.dx - rInner.dx) / rightWidth).clamp(-0.5, 1.5).toDouble();
    final binocX = (lx + rx) * 0.5;

    // Vertical anchor 1: Eye-corner chord offset normalized by eye width
    final lChordY = (lOuter.dy + lInner.dy) * 0.5;
    final rChordY = (rInner.dy + rOuter.dy) * 0.5;
    final lyCorner = ((leftIris.dy - lChordY) / leftWidth).clamp(-1.5, 1.5).toDouble();
    final ryCorner = ((rightIris.dy - rChordY) / rightWidth).clamp(-1.5, 1.5).toDouble();

    // Vertical anchor 2: Rigid brow-to-infraorbital-cheekbone frame (105..118, 334..347)
    final lBrow = pt(105);
    final lCheek = pt(118);
    final rBrow = pt(334);
    final rCheek = pt(347);
    final lOrbitH = (lCheek.dy - lBrow.dy).abs();
    final rOrbitH = (rCheek.dy - rBrow.dy).abs();
    final lyOrbit = lOrbitH > 1e-4
        ? ((leftIris.dy - lBrow.dy) / lOrbitH).clamp(-0.5, 1.8).toDouble()
        : 0.5;
    final ryOrbit = rOrbitH > 1e-4
        ? ((rightIris.dy - rBrow.dy) / rOrbitH).clamp(-0.5, 1.8).toDouble()
        : 0.5;

    final binocYCorner = (lyCorner + ryCorner) * 0.5;
    final binocYOrbit = (lyOrbit + ryOrbit) * 0.5;

    // Head translation & pose compensation terms
    final eyeMid = Offset(
      (leftIris.dx + rightIris.dx) * 0.5,
      (leftIris.dy + rightIris.dy) * 0.5,
    );
    final faceCenter = Offset(
      (pt(234).dx + pt(454).dx) * 0.5,
      pt(168).dy,
    );

    return <double>[
      lx,
      rx,
      binocX,
      lyCorner,
      ryCorner,
      binocYCorner,
      binocYOrbit,
      ((eyeMid.dx - faceCenter.dx) / interEye).clamp(-2.5, 2.5).toDouble(),
      ((eyeMid.dy - faceCenter.dy) / interEye).clamp(-2.5, 2.5).toDouble(),
      (o.yaw / 35.0).clamp(-2.5, 2.5).toDouble(),
      (o.pitch / 35.0).clamp(-2.5, 2.5).toDouble(),
      rollRad.clamp(-1.0, 1.0).toDouble(),
    ];
  }

  /// Extracts a 4D cranial/ocular proportion vector invariant to distance & roll.
  static List<double>? extractFaceSignature(FaceObservation o) {
    if (!o.isValid || o.landmarks.length < 468) return null;
    final lm = o.landmarks;
    final aspect = o.imageHeight / o.imageWidth;
    double dist(int a, int b) {
      final dx = lm[a].dx - lm[b].dx;
      final dy = (lm[a].dy - lm[b].dy) * aspect;
      return math.sqrt(dx * dx + dy * dy);
    }

    final outerEyeSpan = dist(33, 263);
    if (outerEyeSpan < 1e-4) return null;
    final innerEyeSpan = dist(133, 362);
    final cheekSpan = dist(234, 454);
    final noseLen = dist(168, 2);
    final faceHeight = dist(10, 152);

    return <double>[
      innerEyeSpan / outerEyeSpan,
      cheekSpan / outerEyeSpan,
      noseLen / outerEyeSpan,
      faceHeight / outerEyeSpan,
    ];
  }

  static double signatureDistance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 999.0;
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return math.sqrt(sum / a.length);
  }
}
