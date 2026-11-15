import 'package:flutter/material.dart';

import '../../services/camera/jetson_camera_service.dart';
import '../theme/app_theme.dart';

/// Live JPEG view from the Jetson camera (via the CT105 relay).
class JetsonCameraView extends StatelessWidget {
  const JetsonCameraView({super.key, required this.stream});

  final JetsonCameraService stream;

  @override
  Widget build(BuildContext context) {
    final frame = stream.frame;
    if (frame == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stream.connecting
                  ? Icons.videocam_outlined
                  : Icons.videocam_off_outlined,
              color: AppColors.muted,
              size: 38,
            ),
            const SizedBox(height: 8),
            Text(
              stream.connecting ? '連接 Jetson 鏡頭…' : 'Jetson 鏡頭未連線',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (stream.error != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  stream.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.danger, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Image.memory(
          frame,
          gaplessPlayback: true,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stream.isFresh
                  ? 'Jetson 鏡頭 ${stream.fps.toStringAsFixed(1)} fps'
                  : 'Jetson 鏡頭中斷（最後畫面 ${stream.ageSeconds}s）',
              style: TextStyle(
                color: stream.isFresh ? AppColors.success : AppColors.warning,
                fontSize: 9,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
