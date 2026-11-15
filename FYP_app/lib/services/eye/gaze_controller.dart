import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/face_observation.dart';
import '../camera_service.dart';
import '../settings_store.dart';
import 'blink_dwell_detector.dart';
import 'face_mesh_engine.dart';
import 'gaze_calibration.dart';
import 'gaze_features.dart';

enum GazeCalibrationState { idle, settling, collecting, fitting, done, failed }

class GazeRegion {
  const GazeRegion({required this.id, required this.rect, this.label});

  final String id;
  final Rect rect;
  final String? label;
}

class SavedEyeProfile {
  SavedEyeProfile({
    required this.id,
    required this.name,
    required this.model,
    required this.faceSignature,
    required this.savedAtIso,
  });

  static SavedEyeProfile? tryFromJson(Map<String, dynamic> j) {
    final modelMap = j['model'];
    if (modelMap is! Map) return null;
    final m = GazeCalibrationModel.tryFromJson(modelMap.cast<String, dynamic>());
    if (m == null) return null;
    return SavedEyeProfile(
      id: '${j['id'] ?? 'default'}',
      name: '${j['name'] ?? '預設用家'}',
      model: m,
      faceSignature: ((j['faceSignature'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      savedAtIso: '${j['savedAtIso'] ?? ''}',
    );
  }

  final String id;
  final String name;
  final GazeCalibrationModel model;
  final List<double> faceSignature;
  final String savedAtIso;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model.toJson(),
        'faceSignature': faceSignature,
        'savedAtIso': savedAtIso,
      };
}

/// Industry-standard 1€ Adaptive Low-Pass Filter (Casiez et al., CHI 2012):
/// Eliminates stationary jitter while preserving instant responsiveness during
/// fast eye saccades across the screen!
class _OneEuroAxis {
  _OneEuroAxis({
    this.minCutoff = 0.72,
    this.beta = 0.048,
    this.dCutoff = 1.0,
  });

  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _xPrev;
  double _dxPrev = 0.0;
  int? _tPrevMs;

  double filter(double x, int tMs) {
    if (_xPrev == null || _tPrevMs == null) {
      _xPrev = x;
      _tPrevMs = tMs;
      return x;
    }
    final dt = ((tMs - _tPrevMs!).clamp(8, 250)) / 1000.0;
    _tPrevMs = tMs;

    final dx = (x - _xPrev!) / dt;
    final aD = _alpha(dCutoff, dt);
    final edx = aD * dx + (1.0 - aD) * _dxPrev;
    _dxPrev = edx;

    final cutoff = minCutoff + beta * edx.abs();
    final a = _alpha(cutoff, dt);
    final xHat = a * x + (1.0 - a) * _xPrev!;
    _xPrev = xHat;
    return xHat;
  }

  double _alpha(double cutoffHz, double dtSec) {
    final tau = 1.0 / (2.0 * math.pi * cutoffHz);
    return 1.0 / (1.0 + tau / dtSec);
  }

  void reset() {
    _xPrev = null;
    _dxPrev = 0.0;
    _tPrevMs = null;
  }
}

/// Upgraded v3 Gaze & Facial-Profile Controller:
/// - 1€ Adaptive Filter replaces sluggish triple moving-average lag.
/// - Magnetic button gravity assist + 280ms grace decay prevents annoying dwell resets!
/// - Quick 5-Point (~7.5s) & Precision 9-Point calibration modes.
/// - 1-Tap Center Drift Zeroing (`recenterNow()`) compensates posture shifts instantly!
/// - Default Heuristic Pre-Calibration Mode: even BEFORE calibration, head + iris
///   gives immediate responsive cursor movement so users see instant feedback!
class GazeController extends ChangeNotifier {
  GazeController({
    required this.camera,
    required this.engine,
    required this.settings,
  });

  static const _kProfilesKey = 'gaze_saved_profiles_v3';
  static const _kActiveProfileIdKey = 'gaze_active_profile_id_v3';

  final CameraService camera;
  final FaceMeshEngine engine;
  final SettingsStore settings;

  SharedPreferences? _prefs;
  final List<SavedEyeProfile> profiles = [];
  SavedEyeProfile? activeProfile;
  bool faceRecognizedMatch = false;

  bool running = false;
  bool initializing = false;
  bool faceDetected = false;
  String? error;
  String faceHint = '請將臉部置於鏡頭正前方';

  Offset? gaze;
  Offset? stableGaze;
  String? hoveredId;
  String? lastTriggeredId;
  int triggerSeq = 0;
  bool eyesClosed = false;
  double selectionProgress = 0;
  double fps = 0;

  GazeCalibrationModel? model;
  GazeCalibrationState calibrationState = GazeCalibrationState.idle;
  int calibrationIndex = 0;
  Offset? calibrationTarget;
  double calibrationProgress = 0;
  int calibrationSampleCount = 0;
  double? calibrationRmse;
  String? calibrationMessage;
  String pendingProfileName = '用家 1';
  bool quickMode5Point = true;

  static const List<Offset> targets5Point = [
    Offset(0.50, 0.50),
    Offset(0.16, 0.18),
    Offset(0.84, 0.18),
    Offset(0.16, 0.82),
    Offset(0.84, 0.82),
  ];

  static const List<Offset> targets9Point = [
    Offset(0.15, 0.16),
    Offset(0.50, 0.16),
    Offset(0.85, 0.16),
    Offset(0.15, 0.50),
    Offset(0.50, 0.50),
    Offset(0.85, 0.50),
    Offset(0.15, 0.84),
    Offset(0.50, 0.84),
    Offset(0.85, 0.84),
  ];

  List<Offset> _activeTargets = targets5Point;
  List<Offset> get activeCalibrationTargets => _activeTargets;

  final BlinkDwellDetector _blink = BlinkDwellDetector();
  final _OneEuroAxis _euroX = _OneEuroAxis();
  final _OneEuroAxis _euroY = _OneEuroAxis();

  Offset _centerBias = Offset.zero;
  Offset? _lastRawPrediction;
  List<double>? _latestFeatures;
  List<double>? _uncalibratedNeutral;

  final List<CalibrationSample> _calibrationSamples = [];
  final List<List<double>> _calibrationFaceSigs = [];
  final List<double> _blinkOpenScores = [];
  final List<GazeRegion> _regions = [];
  final List<List<double>> _liveSigWindow = [];

  String? _dwellHoverId;
  double _dwellAccumMs = 0;
  int _lastDwellTickMs = 0;
  int _dwellCooldownUntilMs = 0;

  int _lastProcessMs = 0;
  int _lastNotifyMs = 0;
  bool _processingFrame = false;
  int _frames = 0;
  int _fpsStartMs = 0;
  Timer? _calibrationTimer;
  int _calibrationPhaseStartMs = 0;
  bool _collecting = false;

  void Function(String id)? onTrigger;
  void Function(String message)? onMessage;

  List<GazeRegion> get regions => List.unmodifiable(_regions);

  Future<void> loadSavedProfiles() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    profiles.clear();
    final raw = p.getString(_kProfilesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final item in list) {
          final parsed = SavedEyeProfile.tryFromJson(item);
          if (parsed != null) profiles.add(parsed);
        }
      } catch (_) {}
    }
    final activeId = p.getString(_kActiveProfileIdKey);
    if (profiles.isNotEmpty) {
      final found =
          profiles.where((e) => e.id == activeId).firstOrNull ?? profiles.first;
      _applyProfile(found, matchedByFace: false);
    }
    notifyListeners();
  }

  void _applyProfile(SavedEyeProfile profile, {required bool matchedByFace}) {
    activeProfile = profile;
    model = profile.model;
    calibrationRmse = profile.model.rmse;
    _blink.personalize(profile.model.blinkBaseline);
    calibrationState = GazeCalibrationState.done;
    faceRecognizedMatch = matchedByFace;
    _centerBias = Offset.zero;
    _euroX.reset();
    _euroY.reset();
    calibrationMessage = matchedByFace
        ? '已透過面部特徵自動識別「${profile.name}」並載入眼控檔案'
        : '已載入「${profile.name}」嘅眼控檔案（免重新校準）';
    _prefs?.setString(_kActiveProfileIdKey, profile.id);
  }

  /// Instant 1-tap posture drift re-centering: look at the middle of the screen
  /// and tap/trigger once to zero out any vertical/horizontal shift!
  void recenterNow() {
    if (_lastRawPrediction != null) {
      _centerBias = Offset(
        _lastRawPrediction!.dx - 0.5,
        _lastRawPrediction!.dy - 0.5,
      );
    } else if (_latestFeatures != null) {
      _uncalibratedNeutral = List<double>.from(_latestFeatures!);
      _centerBias = Offset.zero;
    }
    _euroX.reset();
    _euroY.reset();
    calibrationMessage = '已完成視線中心歸零修正！';
    notifyListeners();
  }

  Future<void> selectProfile(String id) async {
    final found = profiles.where((e) => e.id == id).firstOrNull;
    if (found == null) return;
    _applyProfile(found, matchedByFace: false);
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    profiles.removeWhere((e) => e.id == id);
    if (activeProfile?.id == id) {
      if (profiles.isNotEmpty) {
        _applyProfile(profiles.first, matchedByFace: false);
      } else {
        activeProfile = null;
        model = null;
        calibrationRmse = null;
        calibrationState = GazeCalibrationState.idle;
        calibrationMessage = null;
      }
    }
    await _persistProfiles();
    notifyListeners();
  }

  Future<void> _persistProfiles() async {
    await _prefs?.setString(
      _kProfilesKey,
      jsonEncode(profiles.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> start() async {
    if (running || initializing) return;
    initializing = true;
    error = null;
    notifyListeners();
    if (_prefs == null) {
      await loadSavedProfiles();
    }
    try {
      final ok = await camera.use(
        CameraLensDirection.front,
        preset: ResolutionPreset.medium,
      );
      if (!ok) throw StateError(camera.error ?? '無法開啟前置鏡頭');
      await engine.initialize();
      await camera.startImageStream(_onFrame);
      running = true;
      _fpsStartMs = DateTime.now().millisecondsSinceEpoch;
    } catch (e) {
      error = '$e';
      running = false;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    running = false;
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    await camera.stopImageStream();
    notifyListeners();
  }

  void setRegions(List<GazeRegion> regions) {
    _regions
      ..clear()
      ..addAll(regions);
  }

  void _onFrame(CameraImage image) {
    if (_processingFrame) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastProcessMs < 36) return; // ~28 FPS smooth tracking
    _lastProcessMs = nowMs;
    _processingFrame = true;

    try {
      _frames++;
      final rotation = camera.rotationDegrees;
      if (rotation == null) return;
      final FaceObservation? obs = engine.process(
        image,
        rotationDegrees: rotation,
        mirrorHorizontal: camera.mirrorHorizontal,
      );

      if (obs == null || !obs.isValid) {
        faceDetected = false;
        eyesClosed = false;
        faceHint = '未偵測到完整面部，請對準前鏡頭並保持光線充足';
        _decayDwell(nowMs);
        _updateFps(nowMs);
        _maybeNotify(nowMs);
        return;
      }
      faceDetected = true;
      _updateFaceQualityHint(obs);

      // Automatic Face+Eye profile recognition
      final liveSig = GazeFeatures.extractFaceSignature(obs);
      if (liveSig != null &&
          calibrationState != GazeCalibrationState.settling &&
          calibrationState != GazeCalibrationState.collecting &&
          profiles.isNotEmpty) {
        _liveSigWindow.add(liveSig);
        if (_liveSigWindow.length > 12) _liveSigWindow.removeAt(0);
        if (_liveSigWindow.length >= 8) {
          final avgSig = _averageVectors(_liveSigWindow);
          SavedEyeProfile? best;
          var bestDist = 999.0;
          for (final p in profiles) {
            if (p.faceSignature.length != avgSig.length) continue;
            final d = GazeFeatures.signatureDistance(avgSig, p.faceSignature);
            if (d < bestDist) {
              bestDist = d;
              best = p;
            }
          }
          if (best != null && bestDist < 0.085) {
            faceRecognizedMatch = true;
            if (activeProfile?.id != best.id) {
              _applyProfile(best, matchedByFace: true);
            }
          }
        }
      }

      final features = GazeFeatures.extract(obs);
      final blink = _blink.onSample(nowMs, obs.blinkLeft, obs.blinkRight);
      eyesClosed = blink.eyesClosed;
      final eyesOpen = !blink.eyesClosed;

      if (features != null) {
        _latestFeatures = features;
      }

      // Predict gaze: either calibrated model OR instant pre-calibration heuristic!
      if (features != null && eyesOpen) {
        Offset rawPred;
        if (model != null && model!.isCompatible) {
          rawPred = model!.predict(features);
          _lastRawPrediction = rawPred;
        } else {
          // Instant pre-calibration fallback using binocular iris + head yaw/pitch
          _uncalibratedNeutral ??= List<double>.from(features);
          final base = _uncalibratedNeutral!;
          final dx = (features[2] - base[2]) * 4.8 + (features[9] - base[9]) * 1.4;
          final dy = (features[5] - base[5]) * 6.5 +
              (features[6] - base[6]) * 4.0 +
              (features[10] - base[10]) * 1.5;
          rawPred = Offset(0.5 + dx, 0.5 + dy);
          _lastRawPrediction = rawPred;
        }

        // Apply center bias & sensitivity gain
        final gain = settings.eyeSensitivity;
        final gainedX = ((rawPred.dx - _centerBias.dx - 0.5) * gain + 0.5)
            .clamp(0.01, 0.99)
            .toDouble();
        final gainedY = ((rawPred.dy - _centerBias.dy - 0.5) * gain + 0.5)
            .clamp(0.01, 0.99)
            .toDouble();

        // 1€ Adaptive Low-Pass Filter
        final fx = _euroX.filter(gainedX, nowMs);
        final fy = _euroY.filter(gainedY, nowMs);
        var filtered = Offset(fx.clamp(0.0, 1.0), fy.clamp(0.0, 1.0));

        // Magnetic button snapping (gentle 26% pull toward hovered target center)
        final hit = _hitTestRegion(filtered);
        if (hit != null &&
            calibrationState != GazeCalibrationState.settling &&
            calibrationState != GazeCalibrationState.collecting) {
          final c = hit.rect.center;
          filtered = Offset(
            filtered.dx + 0.26 * (c.dx - filtered.dx),
            filtered.dy + 0.26 * (c.dy - filtered.dy),
          );
          hoveredId = hit.id;
        } else {
          hoveredId = null;
        }

        gaze = filtered;
        stableGaze = filtered;
      }

      // Collect calibration samples
      if (calibrationState == GazeCalibrationState.collecting &&
          _collecting &&
          features != null &&
          eyesOpen &&
          calibrationTarget != null) {
        _calibrationSamples.add(CalibrationSample(
          features: List<double>.from(features),
          target: calibrationTarget!,
        ));
        if (liveSig != null) {
          _calibrationFaceSigs.add(liveSig);
        }
        calibrationSampleCount = _calibrationSamples.length;
        final openScore = math.max(obs.blinkLeft, obs.blinkRight);
        if (openScore < 0.5) _blinkOpenScores.add(openScore);
      }

      // Dwell / Blink Click State Machine with 280ms Grace Decay!
      final dt = _lastDwellTickMs == 0
          ? 36.0
          : (nowMs - _lastDwellTickMs).clamp(10, 150).toDouble();
      _lastDwellTickMs = nowMs;

      final dwellTargetMs = settings.eyeDwellMs.toDouble();
      if (settings.eyeClickMode == 'dwell') {
        if (nowMs < _dwellCooldownUntilMs) {
          selectionProgress = 0;
          _dwellAccumMs = 0;
        } else if (hoveredId != null && hoveredId == _dwellHoverId) {
          _dwellAccumMs += dt;
          selectionProgress = (_dwellAccumMs / dwellTargetMs).clamp(0.0, 1.0);
          if (_dwellAccumMs >= dwellTargetMs) {
            final triggered = hoveredId!;
            _dwellAccumMs = 0;
            selectionProgress = 0;
            _dwellCooldownUntilMs = nowMs + 1250;
            lastTriggeredId = triggered;
            triggerSeq++;
            onTrigger?.call(triggered);
          }
        } else if (hoveredId != null && hoveredId != _dwellHoverId) {
          _dwellHoverId = hoveredId;
          _dwellAccumMs = dt;
          selectionProgress = (_dwellAccumMs / dwellTargetMs).clamp(0.0, 1.0);
        } else {
          // Grace decay instead of harsh zero reset on 1-2 frame flicker!
          _dwellAccumMs = math.max(0.0, _dwellAccumMs - dt * 1.8);
          selectionProgress = (_dwellAccumMs / dwellTargetMs).clamp(0.0, 1.0);
          if (_dwellAccumMs <= 0) _dwellHoverId = null;
        }
      } else {
        selectionProgress = blink.progress;
        if (blink.triggered && hoveredId != null) {
          lastTriggeredId = hoveredId;
          triggerSeq++;
          onTrigger?.call(hoveredId!);
        }
      }

      _updateFps(nowMs);
      _maybeNotify(nowMs);
    } finally {
      _processingFrame = false;
    }
  }

  void _decayDwell(int nowMs) {
    final dt = _lastDwellTickMs == 0
        ? 40.0
        : (nowMs - _lastDwellTickMs).clamp(10, 200).toDouble();
    _lastDwellTickMs = nowMs;
    _dwellAccumMs = math.max(0.0, _dwellAccumMs - dt * 1.5);
    selectionProgress =
        (_dwellAccumMs / settings.eyeDwellMs.toDouble()).clamp(0.0, 1.0);
  }

  void _updateFaceQualityHint(FaceObservation o) {
    if (o.roll.abs() > 18) {
      faceHint = '頭部傾側較大（系統已自動補償角度）';
    } else if (o.yaw.abs() > 22) {
      faceHint = '請稍微將臉轉向螢幕正中央';
    } else {
      faceHint = '面部與雙眼追蹤穩定（${fps.toStringAsFixed(0)} FPS）';
    }
  }

  GazeRegion? _hitTestRegion(Offset point) {
    // Expand hit box slightly (1.8%) for generous elderly/ALS accessibility
    for (var i = _regions.length - 1; i >= 0; i--) {
      final padded = _regions[i].rect.inflate(0.018);
      if (padded.contains(point)) return _regions[i];
    }
    return null;
  }

  List<double> _averageVectors(List<List<double>> list) {
    final dim = list.first.length;
    final sum = List<double>.filled(dim, 0);
    for (final v in list) {
      for (var i = 0; i < dim; i++) {
        sum[i] += v[i];
      }
    }
    return List<double>.generate(dim, (i) => sum[i] / list.length);
  }

  void _updateFps(int nowMs) {
    if (nowMs - _fpsStartMs >= 500) {
      fps = _frames * 1000.0 / (nowMs - _fpsStartMs);
      _frames = 0;
      _fpsStartMs = nowMs;
    }
  }

  void _maybeNotify(int nowMs) {
    if (nowMs - _lastNotifyMs < 40) return;
    _lastNotifyMs = nowMs;
    notifyListeners();
  }

  void startCalibration({String? profileName, bool quick5Point = true}) {
    quickMode5Point = quick5Point;
    _activeTargets = quick5Point ? targets5Point : targets9Point;
    if (profileName != null && profileName.trim().isNotEmpty) {
      pendingProfileName = profileName.trim();
    } else if (activeProfile != null) {
      pendingProfileName = activeProfile!.name;
    } else {
      pendingProfileName = '用家 ${profiles.length + 1}';
    }
    calibrationState = GazeCalibrationState.settling;
    calibrationIndex = 0;
    calibrationTarget = _activeTargets.first;
    calibrationProgress = 0;
    calibrationSampleCount = 0;
    calibrationRmse = null;
    _centerBias = Offset.zero;
    calibrationMessage =
        '請注視發光圓點（共 ${_activeTargets.length} 點，保持頭部自然不動）';
    _calibrationSamples.clear();
    _calibrationFaceSigs.clear();
    _blinkOpenScores.clear();
    _collecting = false;
    _calibrationPhaseStartMs = DateTime.now().millisecondsSinceEpoch;
    _calibrationTimer?.cancel();
    _calibrationTimer = Timer.periodic(
      const Duration(milliseconds: 45),
      (_) => _tickCalibration(),
    );
    notifyListeners();
  }

  void _tickCalibration() {
    if (calibrationState == GazeCalibrationState.idle ||
        calibrationState == GazeCalibrationState.done ||
        calibrationState == GazeCalibrationState.failed) {
      _calibrationTimer?.cancel();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _calibrationPhaseStartMs;
    final settleMs = quickMode5Point ? 550.0 : 700.0;
    final collectMs = quickMode5Point ? 1150.0 : 1450.0;

    if (calibrationState == GazeCalibrationState.settling) {
      calibrationProgress = (elapsed / settleMs).clamp(0.0, 1.0);
      if (elapsed >= settleMs) {
        calibrationState = GazeCalibrationState.collecting;
        _collecting = true;
        _calibrationPhaseStartMs = now;
        calibrationMessage =
            '正在記錄視線點（${calibrationIndex + 1}/${_activeTargets.length}）…';
      }
    } else if (calibrationState == GazeCalibrationState.collecting) {
      calibrationProgress = (elapsed / collectMs).clamp(0.0, 1.0);
      if (elapsed >= collectMs) {
        _collecting = false;
        calibrationIndex++;
        if (calibrationIndex >= _activeTargets.length) {
          _finishCalibration();
        } else {
          calibrationState = GazeCalibrationState.settling;
          calibrationTarget = _activeTargets[calibrationIndex];
          calibrationProgress = 0;
          _calibrationPhaseStartMs = now;
          calibrationMessage =
              '請看向下一點（${calibrationIndex + 1}/${_activeTargets.length}）';
        }
      }
    }
    notifyListeners();
  }

  Future<void> _finishCalibration() async {
    _calibrationTimer?.cancel();
    calibrationState = GazeCalibrationState.fitting;
    calibrationTarget = null;
    calibrationMessage = '正在擬合 12 維眼控模型並儲存檔案…';
    notifyListeners();
    try {
      final minRaw = quickMode5Point ? 12 : 18;
      if (_calibrationSamples.length < minRaw) {
        throw StateError('收集樣本不足，請保持臉部在鏡頭正前方並重試');
      }
      final baseline = _percentile(_blinkOpenScores, 0.9);
      final meanSamples = <CalibrationSample>[];
      for (final target in _activeTargets) {
        final group = _calibrationSamples
            .where((s) => (s.target - target).distance < 1e-6)
            .toList(growable: false);
        if (group.isEmpty) continue;
        final filtered = rejectCalibrationOutliers(group, minKeep: 4);
        final mean = List<double>.filled(GazeFeatures.size, 0);
        for (final s in filtered) {
          for (var i = 0; i < GazeFeatures.size; i++) {
            mean[i] += s.features[i];
          }
        }
        for (var i = 0; i < GazeFeatures.size; i++) {
          mean[i] /= filtered.length;
        }
        meanSamples.add(CalibrationSample(features: mean, target: target));
      }
      final minValidPoints = quickMode5Point ? 5 : 7;
      if (meanSamples.length < minValidPoints) {
        throw StateError(
            '有效校準點不足（${meanSamples.length}/${_activeTargets.length}），請重試');
      }
      final m = GazeCalibrationModel.fit(
        meanSamples,
        blinkBaseline: baseline,
      );
      final faceSig = _calibrationFaceSigs.isNotEmpty
          ? _averageVectors(_calibrationFaceSigs)
          : const <double>[];

      final id = 'profile_${pendingProfileName.hashCode.abs()}';
      final saved = SavedEyeProfile(
        id: id,
        name: pendingProfileName,
        model: m,
        faceSignature: faceSig,
        savedAtIso: DateTime.now().toIso8601String(),
      );
      final existingIdx =
          profiles.indexWhere((e) => e.name == pendingProfileName);
      if (existingIdx >= 0) {
        profiles[existingIdx] = saved;
      } else {
        profiles.add(saved);
      }
      await _persistProfiles();
      _applyProfile(saved, matchedByFace: true);
      calibrationMessage =
          '校準完成！已儲存「${saved.name}」（誤差 ${(m.rmse * 100).toStringAsFixed(1)}%）。如有偏移可隨時撳「一鍵視線歸零」。';
    } catch (e) {
      calibrationState = GazeCalibrationState.failed;
      calibrationMessage = '$e';
    }
    notifyListeners();
  }

  void cancelCalibration() {
    _calibrationTimer?.cancel();
    _calibrationTimer = null;
    calibrationState =
        model != null ? GazeCalibrationState.done : GazeCalibrationState.idle;
    calibrationTarget = null;
    calibrationProgress = 0;
    _calibrationSamples.clear();
    _calibrationFaceSigs.clear();
    _blinkOpenScores.clear();
    _collecting = false;
    calibrationMessage = null;
    notifyListeners();
  }

  double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.35;
    final sorted = List<double>.from(values)..sort();
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  @override
  void dispose() {
    _calibrationTimer?.cancel();
    engine.dispose();
    super.dispose();
  }
}
