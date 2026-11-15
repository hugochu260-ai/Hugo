import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/radar_models.dart';

class RadarPainter extends CustomPainter {
  RadarPainter({
    required this.scan,
    required this.rangeM,
    required this.palette,
  });

  final RadarScan? scan;
  final double rangeM;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 16;
    if (radius <= 0) return;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = palette.outline;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4.0, grid);
    }
    canvas.drawLine(
      center.translate(-radius, 0),
      center.translate(radius, 0),
      grid,
    );
    canvas.drawLine(
      center.translate(0, -radius),
      center.translate(0, radius),
      grid,
    );

    final front = Paint()..color = palette.success.withValues(alpha: 0.10);
    final rear = Paint()..color = palette.warning.withValues(alpha: 0.10);
    final sectorRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      sectorRect,
      -math.pi / 2 - 35 * math.pi / 180,
      70 * math.pi / 180,
      true,
      front,
    );
    canvas.drawArc(
      sectorRect,
      math.pi / 2 - 35 * math.pi / 180,
      70 * math.pi / 180,
      true,
      rear,
    );

    final labelStyle = TextStyle(
      color: palette.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    for (var i = 1; i <= 4; i++) {
      final d = rangeM * i / 4.0;
      final label = d < 3 ? '${d.toStringAsFixed(1)}m' : '${d.toStringAsFixed(0)}m';
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center.translate(5, -radius * i / 4.0));
    }

    final points = scan?.points ?? const <RadarPoint>[];
    for (final p in points) {
      if (p.rangeM > rangeM) continue;
      final a = p.angleDeg * math.pi / 180.0;
      final r = (p.rangeM / rangeM) * radius;
      final pos = Offset(
        center.dx + r * math.sin(a),
        center.dy - r * math.cos(a),
      );
      final color = p.rangeM < 0.7
          ? palette.danger
          : p.rangeM < 1.2
              ? palette.warning
              : palette.primary;
      canvas.drawCircle(
        pos,
        p.rangeM < 1.0 ? 3.0 : 2.1,
        Paint()..color = color.withValues(alpha: 0.88),
      );
    }

    final car = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 18, height: 26),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      car,
      Paint()..color = palette.primary.withValues(alpha: 0.20),
    );
    canvas.drawRRect(
      car,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = palette.primary,
    );
    final nose = Path()
      ..moveTo(center.dx, center.dy - 20)
      ..lineTo(center.dx - 6, center.dy - 11)
      ..lineTo(center.dx + 6, center.dy - 11)
      ..close();
    canvas.drawPath(nose, Paint()..color = palette.primary);
  }

  @override
  bool shouldRepaint(covariant RadarPainter old) =>
      old.scan != scan || old.rangeM != rangeM || old.palette.isLight != palette.isLight;
}

/// Supports two-finger pinch-to-zoom (1m .. 30m) when [onRangeChanged] is provided!
class RadarPlot extends StatefulWidget {
  const RadarPlot({
    super.key,
    required this.scan,
    required this.rangeM,
    this.height,
    this.onRangeChanged,
  });

  final RadarScan? scan;
  final double rangeM;
  final double? height;
  final ValueChanged<double>? onRangeChanged;

  @override
  State<RadarPlot> createState() => _RadarPlotState();
}

class _RadarPlotState extends State<RadarPlot> {
  double _baseRange = 5.0;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final plot = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: RadarPainter(
          scan: widget.scan,
          rangeM: widget.rangeM,
          palette: p,
        ),
      ),
    );
    if (widget.onRangeChanged == null) return plot;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _baseRange = widget.rangeM,
      onScaleUpdate: (details) {
        if ((details.scale - 1.0).abs() < 0.02) return;
        // Pinch out (scale > 1) zooms in (smaller meter range)
        final next = (_baseRange / details.scale).clamp(1.0, 30.0);
        widget.onRangeChanged!(next);
      },
      child: plot,
    );
  }
}
