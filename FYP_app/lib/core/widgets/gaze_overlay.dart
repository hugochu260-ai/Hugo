import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GazeOverlayPainter extends CustomPainter {
  GazeOverlayPainter({
    required this.gaze,
    required this.progress,
    required this.calibrationTarget,
    required this.calibrationProgress,
    required this.eyesClosed,
  });

  /// Normalised gaze (0..1).
  final Offset? gaze;
  final double progress;
  final Offset? calibrationTarget;
  final double calibrationProgress;
  final bool eyesClosed;

  @override
  void paint(Canvas canvas, Size size) {
    if (calibrationTarget != null) {
      final p = Offset(
        calibrationTarget!.dx * size.width,
        calibrationTarget!.dy * size.height,
      );
      final base = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawCircle(p, 26, base);
      canvas.drawCircle(
        p,
        20,
        Paint()..color = AppColors.primary.withValues(alpha: 0.16),
      );
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 31),
        -math.pi / 2,
        calibrationProgress * math.pi * 2,
        false,
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(p, 4, Paint()..color = AppColors.secondary);
    }

    final g = gaze;
    if (g == null) return;
    final p = Offset(g.dx * size.width, g.dy * size.height);
    final color = eyesClosed ? AppColors.secondary : AppColors.primary;

    canvas.drawCircle(
      p,
      18,
      Paint()..color = color.withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      p,
      10,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(p, 3.2, Paint()..color = color);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: 22),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GazeOverlayPainter old) =>
      old.gaze != gaze ||
      old.progress != progress ||
      old.calibrationTarget != calibrationTarget ||
      old.calibrationProgress != calibrationProgress ||
      old.eyesClosed != eyesClosed;
}

class GazeOverlay extends StatelessWidget {
  const GazeOverlay({
    super.key,
    required this.gaze,
    required this.progress,
    this.calibrationTarget,
    this.calibrationProgress = 0,
    this.eyesClosed = false,
  });

  final Offset? gaze;
  final double progress;
  final Offset? calibrationTarget;
  final double calibrationProgress;
  final bool eyesClosed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: GazeOverlayPainter(
          gaze: gaze,
          progress: progress,
          calibrationTarget: calibrationTarget,
          calibrationProgress: calibrationProgress,
          eyesClosed: eyesClosed,
        ),
      ),
    );
  }
}
