import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Round portrait. A saved photo replaces the drawn default.
class AssistantPortrait extends StatelessWidget {
  const AssistantPortrait({super.key, this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';
    final file = path.isEmpty ? null : File(path);
    final hasPhoto = file != null && file.existsSync();
    return ClipOval(
      child: hasPhoto
          ? Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => const CustomPaint(painter: AssistantFacePainter()),
            )
          : const CustomPaint(
              painter: AssistantFacePainter(),
              child: SizedBox.expand(),
            ),
    );
  }
}

/// Friendly default face, used until a photo is chosen.
class AssistantFacePainter extends CustomPainter {
  const AssistantFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bg = Paint()..color = const Color(0xFFFFF6EC);
    canvas.drawRect(Offset.zero & size, bg);

    final hair = Paint()..color = const Color(0xFF2A211C);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.34),
        width: w * 0.86,
        height: h * 0.62,
      ),
      hair,
    );

    final skin = Paint()..color = const Color(0xFFFFD7B5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.46),
        width: w * 0.62,
        height: h * 0.58,
      ),
      skin,
    );

    final cheek = Paint()..color = const Color(0xFFFFB4A2);
    canvas.drawCircle(Offset(w * 0.34, h * 0.52), w * 0.045, cheek);
    canvas.drawCircle(Offset(w * 0.66, h * 0.52), w * 0.045, cheek);

    final eye = Paint()..color = const Color(0xFF2A211C);
    canvas.drawCircle(Offset(w * 0.40, h * 0.44), w * 0.035, eye);
    canvas.drawCircle(Offset(w * 0.60, h * 0.44), w * 0.035, eye);
    final shine = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.412, h * 0.428), w * 0.012, shine);
    canvas.drawCircle(Offset(w * 0.612, h * 0.428), w * 0.012, shine);

    final smile = Paint()
      ..color = const Color(0xFFC45C4A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.54),
        width: w * 0.22,
        height: h * 0.16,
      ),
      0.2,
      2.7,
      false,
      smile,
    );

    final shirt = Paint()..color = AppPalette.light.primary;
    final shirtPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.5, h * 0.62, w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(shirtPath, shirt);
  }

  @override
  bool shouldRepaint(covariant AssistantFacePainter oldDelegate) => false;
}
