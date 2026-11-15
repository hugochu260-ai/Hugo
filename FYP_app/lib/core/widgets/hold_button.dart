import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HoldButton extends StatefulWidget {
  const HoldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onStart,
    required this.onEnd,
    this.color,
    this.size = 76,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final Color? color;
  final double size;
  final bool enabled;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _pressed = false;

  void _down(PointerDownEvent _) {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    widget.onStart();
  }

  void _up([PointerEvent? _]) {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final baseColor = widget.color ?? p.primary;
    final color = widget.enabled ? baseColor : p.muted;
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _pressed ? color.withValues(alpha: 0.25) : p.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pressed ? color : p.outline,
            width: _pressed ? 2.2 : 1.3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: color, size: widget.size * 0.36),
            const SizedBox(height: 3),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
