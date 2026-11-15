import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

import '../../models/face_observation.dart';
import 'camera_frame_adapter.dart';

/// MediaPipe Face Mesh (478 landmarks + iris + blendshapes + head pose).
class FaceMeshEngine {
  FaceDetectorProcessor? _detector;
  FaceMeshProcessor? _mesh;
  FaceBlendshapesProcessor? _blendshapes;
  FaceMeshInferencePipeline? _pipeline;
  bool _ready = false;
  String? error;

  bool get isReady => _ready;

  Future<void> initialize({bool useXnnpack = true}) async {
    if (_ready) return;
    try {
      final delegate =
          useXnnpack ? FaceMeshDelegate.xnnpack : FaceMeshDelegate.cpu;
      _detector = await FaceDetectorProcessor.create(
        model: FaceDetectionModel.shortRange,
        delegate: delegate,
      );
      _mesh = await FaceMeshProcessor.create(
        model: FaceMeshModel.v2,
        delegate: delegate,
      );
      _blendshapes = await FaceBlendshapesProcessor.create(delegate: delegate);
      _pipeline = FaceMeshInferencePipeline(
        detector: _detector!,
        mesh: _mesh!,
      );
      _ready = true;
    } catch (e) {
      error = '$e';
      _ready = false;
      rethrow;
    }
  }

  FaceObservation? process(
    CameraImage image, {
    required int rotationDegrees,
    required bool mirrorHorizontal,
  }) {
    final pipeline = _pipeline;
    if (!_ready || pipeline == null) return null;
    final FaceMeshFrame? frame = Platform.isAndroid
        ? CameraFrameAdapter.toNv21(image)
        : CameraFrameAdapter.toBgra(image);
    if (frame == null) return null;

    final FaceMeshInferenceResult result = pipeline.process(
      frame,
      rotationDegrees: rotationDegrees,
      mirrorHorizontal: mirrorHorizontal,
    );
    final FaceMeshResult? mesh = result.meshResult;
    if (mesh == null || mesh.landmarks.length < 478) return null;

    final FaceBlendshapes? bs = _blendshapes?.process(mesh);
    final geometry = mesh.estimateGeometry();
    final pose = geometry.headPose;

    return FaceObservation(
      landmarks: mesh.landmarks
          .map((l) => Offset(l.x, l.y))
          .toList(growable: false),
      imageWidth: mesh.imageWidth,
      imageHeight: mesh.imageHeight,
      blinkLeft: bs?[FaceBlendshape.eyeBlinkLeft] ?? 0,
      blinkRight: bs?[FaceBlendshape.eyeBlinkRight] ?? 0,
      yaw: pose.yawDegrees,
      pitch: pose.pitchDegrees,
      roll: pose.rollDegrees,
      score: mesh.score,
    );
  }

  void resetTracking() {
    _pipeline?.resetTracking();
  }

  void dispose() {
    _pipeline?.close();
    _blendshapes?.close();
    _pipeline = null;
    _blendshapes = null;
    _mesh = null;
    _detector = null;
    _ready = false;
  }
}
