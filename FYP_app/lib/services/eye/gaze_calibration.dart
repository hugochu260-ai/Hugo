import 'dart:math' as math;
import 'dart:ui';

import 'gaze_features.dart';

class CalibrationSample {
  const CalibrationSample({required this.features, required this.target});

  final List<double> features;

  /// Normalised screen target (0..1).
  final Offset target;
}

/// Ridge-regression gaze model v3 with head-pose interaction terms and
/// inverse-distance local residual warping. Supports both Quick 5-Point and
/// Precision 9-Point calibration!
class GazeCalibrationModel {
  GazeCalibrationModel({
    required this.featureMean,
    required this.featureStd,
    required this.featureMinZ,
    required this.featureMaxZ,
    required this.coefficientsX,
    required this.coefficientsY,
    required this.targets,
    required this.residualX,
    required this.residualY,
    required this.residualScale,
    required this.rmse,
    required this.sampleCount,
    required this.blinkBaseline,
  });

  static const int modelVersion = 2;

  final List<double> featureMean;
  final List<double> featureStd;
  final List<double> featureMinZ;
  final List<double> featureMaxZ;
  final List<double> coefficientsX;
  final List<double> coefficientsY;
  final List<Offset> targets;
  final List<double> residualX;
  final List<double> residualY;
  final double residualScale;
  final double rmse;
  final int sampleCount;
  final double blinkBaseline;

  bool get isCompatible =>
      featureMean.length == GazeFeatures.size &&
      coefficientsX.length == _basisLength;

  static int get _basisLength => 1 + GazeFeatures.size + 2;
  static const double _ridge = 0.14;

  static GazeCalibrationModel fit(
    List<CalibrationSample> samples, {
    double blinkBaseline = 0.35,
  }) {
    if (samples.length < 5) {
      throw StateError('校準樣本不足（${samples.length}），請重試');
    }
    final n = GazeFeatures.size;
    final mean = List<double>.filled(n, 0);
    for (final s in samples) {
      for (var i = 0; i < n; i++) {
        mean[i] += s.features[i];
      }
    }
    for (var i = 0; i < n; i++) {
      mean[i] /= samples.length;
    }

    final std = List<double>.filled(n, 0);
    for (final s in samples) {
      for (var i = 0; i < n; i++) {
        final d = s.features[i] - mean[i];
        std[i] += d * d;
      }
    }
    for (var i = 0; i < n; i++) {
      std[i] = math.sqrt(std[i] / samples.length);
      if (std[i] < 1e-5) std[i] = 1e-5;
    }

    final zs = <List<double>>[];
    for (final s in samples) {
      zs.add(_normalise(s.features, mean, std, null, null));
    }

    final minZ = List<double>.filled(n, double.infinity);
    final maxZ = List<double>.filled(n, -double.infinity);
    for (final z in zs) {
      for (var i = 0; i < n; i++) {
        minZ[i] = math.min(minZ[i], z[i]);
        maxZ[i] = math.max(maxZ[i], z[i]);
      }
    }
    for (var i = 0; i < n; i++) {
      final span = maxZ[i] - minZ[i];
      final margin = span > 1e-5 ? span * 0.35 : 0.8;
      minZ[i] -= margin;
      maxZ[i] += margin;
    }

    final basis = zs
        .map((z) => _basis(_normalise(
            z, List.filled(n, 0), List.filled(n, 1), minZ, maxZ)))
        .toList(growable: false);

    final dim = basis.first.length;
    final normal =
        List<List<double>>.generate(dim, (_) => List<double>.filled(dim, 0));
    final rhsX = List<double>.filled(dim, 0);
    final rhsY = List<double>.filled(dim, 0);

    for (var k = 0; k < samples.length; k++) {
      final b = basis[k];
      for (var i = 0; i < dim; i++) {
        rhsX[i] += b[i] * samples[k].target.dx;
        rhsY[i] += b[i] * samples[k].target.dy;
        for (var j = 0; j < dim; j++) {
          normal[i][j] += b[i] * b[j];
        }
      }
    }

    // Stronger regularization on head-pose interaction terms prevents overfitting
    for (var i = 0; i < dim; i++) {
      final penalty = i == 0
          ? 0.0
          : (i > n ? 0.55 : 0.22);
      normal[i][i] += _ridge * penalty * samples.length;
    }
    final cx = _solve(normal, rhsX);
    final cy = _solve(normal, rhsY);

    final targetMap = <String, Offset>{};
    for (final s in samples) {
      targetMap[
              '${s.target.dx.toStringAsFixed(3)},${s.target.dy.toStringAsFixed(3)}'] =
          s.target;
    }
    final targets = targetMap.values.toList(growable: false);
    final rx = <double>[];
    final ry = <double>[];
    var scale = 0.0;
    if (targets.length >= 2) {
      for (final t in targets) {
        final pred = _predictBaseFromZ(
          _normalise(_meanForTarget(samples, t), mean, std, minZ, maxZ),
          cx,
          cy,
        );
        rx.add(pred.dx - t.dx);
        ry.add(pred.dy - t.dy);
      }
      var sum = 0.0;
      for (var i = 0; i < targets.length; i++) {
        var best = double.infinity;
        for (var j = 0; j < targets.length; j++) {
          if (i == j) continue;
          final d = (targets[i] - targets[j]).distance;
          if (d < best) best = d;
        }
        if (best.isFinite) sum += best;
      }
      scale = targets.isEmpty ? 0.03 : sum / targets.length;
      if (scale < 0.03) scale = 0.03;
    }

    var err = 0.0;
    final tempModel = GazeCalibrationModel(
      featureMean: mean,
      featureStd: std,
      featureMinZ: minZ,
      featureMaxZ: maxZ,
      coefficientsX: cx,
      coefficientsY: cy,
      targets: targets,
      residualX: rx,
      residualY: ry,
      residualScale: scale,
      rmse: 0,
      sampleCount: samples.length,
      blinkBaseline: blinkBaseline,
    );
    for (final s in samples) {
      final p = tempModel.predict(s.features);
      err += math.pow(p.dx - s.target.dx, 2) + math.pow(p.dy - s.target.dy, 2);
    }
    return GazeCalibrationModel(
      featureMean: mean,
      featureStd: std,
      featureMinZ: minZ,
      featureMaxZ: maxZ,
      coefficientsX: cx,
      coefficientsY: cy,
      targets: targets,
      residualX: rx,
      residualY: ry,
      residualScale: scale,
      rmse: math.sqrt(err / samples.length),
      sampleCount: samples.length,
      blinkBaseline: blinkBaseline,
    );
  }

  static List<double> _meanForTarget(
      List<CalibrationSample> samples, Offset target) {
    final n = GazeFeatures.size;
    final out = List<double>.filled(n, 0);
    var count = 0;
    for (final s in samples) {
      if ((s.target - target).distance < 1e-6) {
        for (var i = 0; i < n; i++) {
          out[i] += s.features[i];
        }
        count++;
      }
    }
    if (count == 0) return out;
    for (var i = 0; i < n; i++) {
      out[i] /= count;
    }
    return out;
  }

  static List<double> _normalise(
    List<double> features,
    List<double> mean,
    List<double> std,
    List<double>? minZ,
    List<double>? maxZ,
  ) {
    final n = GazeFeatures.size;
    final out = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      var z = (features[i] - mean[i]) / std[i];
      if (minZ != null) z = z.clamp(minZ[i], maxZ![i]).toDouble();
      out[i] = z;
    }
    return out;
  }

  /// Basis = [1, z0..z11, binocX*yaw, binocY*pitch]
  static List<double> _basis(List<double> z) {
    final out = <double>[1.0, ...z];
    final binocX = z.length > 2 ? z[2] : 0.0;
    final binocY = z.length > 5 ? z[5] : 0.0;
    final yaw = z.length > 9 ? z[9] : 0.0;
    final pitch = z.length > 10 ? z[10] : 0.0;
    out.add((binocX * yaw).clamp(-4.0, 4.0).toDouble());
    out.add((binocY * pitch).clamp(-4.0, 4.0).toDouble());
    return out;
  }

  static Offset _predictBaseFromZ(
      List<double> z, List<double> cx, List<double> cy) {
    final b = _basis(z);
    var x = 0.0;
    var y = 0.0;
    for (var i = 0; i < b.length; i++) {
      x += b[i] * cx[i];
      y += b[i] * cy[i];
    }
    return Offset(x, y);
  }

  Offset predict(List<double> features) {
    if (!isCompatible || features.length != GazeFeatures.size) {
      return const Offset(0.5, 0.5);
    }
    final z =
        _normalise(features, featureMean, featureStd, featureMinZ, featureMaxZ);
    final base = _predictBaseFromZ(z, coefficientsX, coefficientsY);

    if (targets.isEmpty || residualX.isEmpty) {
      return Offset(base.dx.clamp(-0.1, 1.1), base.dy.clamp(-0.1, 1.1));
    }

    final distances = List<int>.generate(targets.length, (i) => i);
    distances.sort((a, b) => (targets[a] - base)
        .distanceSquared
        .compareTo((targets[b] - base).distanceSquared));

    var wx = 0.0;
    var wy = 0.0;
    var wsum = 0.0;
    final k = math.min(4, distances.length);
    for (var i = 0; i < k; i++) {
      final idx = distances[i];
      final d2 = (targets[idx] - base).distanceSquared;
      final w = 1.0 / (d2 / (residualScale * residualScale) + 0.02);
      wx += w * residualX[idx];
      wy += w * residualY[idx];
      wsum += w;
    }
    if (wsum <= 0) {
      return Offset(base.dx.clamp(-0.1, 1.1), base.dy.clamp(-0.1, 1.1));
    }
    return Offset(
      (base.dx - wx / wsum).clamp(-0.1, 1.1),
      (base.dy - wy / wsum).clamp(-0.1, 1.1),
    );
  }

  static List<double> _solve(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = List<List<double>>.generate(n, (i) => <double>[...a[i], b[i]]);
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (m[r][col].abs() > m[pivot][col].abs()) pivot = r;
      }
      if (m[pivot][col].abs() < 1e-12) {
        m[pivot][col] = 1e-6;
      }
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;
      final div = m[col][col];
      for (var j = col; j <= n; j++) {
        m[col][j] /= div;
      }
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = m[r][col];
        if (f == 0) continue;
        for (var j = col; j <= n; j++) {
          m[r][j] -= f * m[col][j];
        }
      }
    }
    return List<double>.generate(n, (i) => m[i][n]);
  }

  Map<String, dynamic> toJson() => {
        'version': modelVersion,
        'featureMean': featureMean,
        'featureStd': featureStd,
        'featureMinZ': featureMinZ,
        'featureMaxZ': featureMaxZ,
        'coefficientsX': coefficientsX,
        'coefficientsY': coefficientsY,
        'targets': targets.map((t) => [t.dx, t.dy]).toList(),
        'residualX': residualX,
        'residualY': residualY,
        'residualScale': residualScale,
        'rmse': rmse,
        'sampleCount': sampleCount,
        'blinkBaseline': blinkBaseline,
      };

  static GazeCalibrationModel? tryFromJson(Map<String, dynamic> json) {
    try {
      final ver = (json['version'] as num?)?.toInt() ?? 1;
      if (ver != modelVersion) return null;
      List<double> d(String k) =>
          (json[k] as List).map((e) => (e as num).toDouble()).toList();
      final m = GazeCalibrationModel(
        featureMean: d('featureMean'),
        featureStd: d('featureStd'),
        featureMinZ: d('featureMinZ'),
        featureMaxZ: d('featureMaxZ'),
        coefficientsX: d('coefficientsX'),
        coefficientsY: d('coefficientsY'),
        targets: (json['targets'] as List)
            .map((e) =>
                Offset((e[0] as num).toDouble(), (e[1] as num).toDouble()))
            .toList(),
        residualX: d('residualX'),
        residualY: d('residualY'),
        residualScale: (json['residualScale'] as num).toDouble(),
        rmse: (json['rmse'] as num).toDouble(),
        sampleCount: (json['sampleCount'] as num).toInt(),
        blinkBaseline: (json['blinkBaseline'] as num?)?.toDouble() ?? 0.35,
      );
      return m.isCompatible ? m : null;
    } catch (_) {
      return null;
    }
  }
}

/// Reject per-target calibration frames whose feature z-score exceeds [maxZ].
List<CalibrationSample> rejectCalibrationOutliers(
  List<CalibrationSample> samples, {
  double maxZ = 2.6,
  int minKeep = 8,
}) {
  if (samples.length <= minKeep) return samples;
  final n = GazeFeatures.size;
  final mean = List<double>.filled(n, 0);
  for (final s in samples) {
    for (var i = 0; i < n; i++) {
      mean[i] += s.features[i];
    }
  }
  for (var i = 0; i < n; i++) {
    mean[i] /= samples.length;
  }
  final std = List<double>.filled(n, 0);
  for (final s in samples) {
    for (var i = 0; i < n; i++) {
      final d = s.features[i] - mean[i];
      std[i] += d * d;
    }
  }
  for (var i = 0; i < n; i++) {
    std[i] = math.sqrt(std[i] / samples.length);
    if (std[i] < 1e-6) std[i] = 1.0;
  }
  final kept = samples.where((s) {
    for (var i = 0; i < n; i++) {
      if ((s.features[i] - mean[i]).abs() / std[i] > maxZ) return false;
    }
    return true;
  }).toList(growable: false);
  return kept.length >= minKeep ? kept : samples;
}
