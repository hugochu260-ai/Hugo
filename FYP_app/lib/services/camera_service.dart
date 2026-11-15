import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;

/// Owns exactly one camera at a time (front for gaze, back for driving).
class CameraService extends ChangeNotifier {
  CameraController? controller;
  CameraDescription? description;
  List<CameraDescription> cameras = const [];
  bool initializing = false;
  String? error;

  bool get isReady => controller?.value.isInitialized ?? false;
  bool get isFront => description?.lensDirection == CameraLensDirection.front;

  Future<bool> use(
    CameraLensDirection lensDirection, {
    ResolutionPreset preset = ResolutionPreset.high,
  }) async {
    if (isReady && description?.lensDirection == lensDirection) {
      return true;
    }
    if (initializing) return false;
    initializing = true;
    error = null;
    notifyListeners();
    await _disposeController();
    try {
      if (cameras.isEmpty) {
        cameras = await availableCameras();
      }
      final matches =
          cameras.where((c) => c.lensDirection == lensDirection).toList();
      if (matches.isEmpty) {
        throw StateError('此裝置沒有${lensDirection == CameraLensDirection.front ? '前置' : '後置'}鏡頭');
      }
      final desc = matches.first;
      final c = CameraController(
        desc,
        preset,
        enableAudio: false,
        imageFormatGroup:
            Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await c.initialize();
      controller = c;
      description = desc;
      notifyListeners();
      return true;
    } catch (e) {
      error = '$e';
      notifyListeners();
      return false;
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> startImageStream(
      void Function(CameraImage image) onFrame) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isStreamingImages) await c.stopImageStream();
    await c.startImageStream((image) {
      onFrame(image);
    });
  }

  Future<void> stopImageStream() async {
    final c = controller;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
  }

  /// Capture a JPEG. Used by the auto-drive loop.
  Future<Uint8List?> takeJpeg() async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    try {
      final file = await c.takePicture();
      return await file.readAsBytes();
    } catch (e) {
      error = '拍照失敗：$e';
      notifyListeners();
      return null;
    }
  }

  /// Rotation compensation for MediaPipe / preview overlays.
  int? get rotationDegrees {
    final c = controller;
    if (c == null || !c.value.isInitialized) return null;
    const map = <DeviceOrientation, int>{
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };
    final device = map[c.value.deviceOrientation] ?? 0;
    final sensor = description?.sensorOrientation ?? 0;
    if (Platform.isIOS) return device;
    if (description?.lensDirection == CameraLensDirection.front) {
      return (sensor + device) % 360;
    }
    return (sensor - device + 360) % 360;
  }

  bool get mirrorHorizontal =>
      !Platform.isIOS && description?.lensDirection == CameraLensDirection.front;

  Future<void> _disposeController() async {
    final c = controller;
    controller = null;
    description = null;
    if (c != null) {
      try {
        if (c.value.isStreamingImages) await c.stopImageStream();
      } catch (_) {}
      try {
        await c.dispose();
      } catch (_) {}
    }
  }

  Future<void> release() async {
    await _disposeController();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }
}
