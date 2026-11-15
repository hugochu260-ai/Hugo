import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/camera_service.dart';

class CameraPreviewBox extends StatelessWidget {
  const CameraPreviewBox({
    super.key,
    required this.camera,
    this.overlay,
    this.fit = BoxFit.cover,
    this.borderRadius = 18,
  });

  final CameraService camera;
  final Widget? overlay;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final controller = camera.controller;
    Widget child;
    if (controller == null || !controller.value.isInitialized) {
      child = Container(
        color: const Color(0xFF05080C),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              camera.initializing
                  ? Icons.hourglass_top_rounded
                  : Icons.videocam_off_outlined,
              color: AppColors.muted,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              camera.initializing ? '鏡頭啟動中…' : '鏡頭未啟動',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (camera.error != null) ...[
              const SizedBox(height: 4),
              Text(
                camera.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 10),
              ),
            ],
          ],
        ),
      );
    } else {
      final preview = CameraPreview(controller);
      child = fit == BoxFit.contain
          ? AspectRatio(aspectRatio: controller.value.aspectRatio, child: preview)
          : FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 720,
                height: controller.value.previewSize?.width ?? 1280,
                child: preview,
              ),
            );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          ?overlay,
        ],
      ),
    );
  }
}
