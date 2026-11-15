import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Corner where the assistant avatar rests after a drag.
enum AssistantCorner { topLeft, topRight, bottomLeft, bottomRight }

AssistantCorner parseAssistantCorner(String raw) {
  for (final corner in AssistantCorner.values) {
    if (corner.name == raw) return corner;
  }
  return AssistantCorner.bottomRight;
}

/// Last character of the assistant name, so「阿智」shows「智」.
String assistantGlyph(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '智';
  return String.fromCharCode(trimmed.runes.last);
}

class AssistantAvatarGeometry {
  static const double size = 64;
  static const double margin = 12;

  static Offset origin({
    required AssistantCorner corner,
    required Size screen,
    required EdgeInsets safe,
  }) {
    final left = safe.left + margin;
    final top = safe.top + margin;
    final right = math.max(left, screen.width - safe.right - size - margin);
    final bottom = math.max(top, screen.height - safe.bottom - size - margin);
    switch (corner) {
      case AssistantCorner.topLeft:
        return Offset(left, top);
      case AssistantCorner.topRight:
        return Offset(right, top);
      case AssistantCorner.bottomLeft:
        return Offset(left, bottom);
      case AssistantCorner.bottomRight:
        return Offset(right, bottom);
    }
  }

  static Offset clamp({
    required Offset topLeft,
    required Size screen,
    required EdgeInsets safe,
  }) {
    final minX = safe.left + margin;
    final minY = safe.top + margin;
    final maxX = math.max(minX, screen.width - safe.right - size - margin);
    final maxY = math.max(minY, screen.height - safe.bottom - size - margin);
    return Offset(
      topLeft.dx.clamp(minX, maxX),
      topLeft.dy.clamp(minY, maxY),
    );
  }

  static AssistantCorner nearest({
    required Offset topLeft,
    required Size screen,
  }) {
    final center = topLeft + const Offset(size / 2, size / 2);
    final isLeft = center.dx < screen.width / 2;
    final isTop = center.dy < screen.height / 2;
    if (isTop && isLeft) return AssistantCorner.topLeft;
    if (isTop) return AssistantCorner.topRight;
    if (isLeft) return AssistantCorner.bottomLeft;
    return AssistantCorner.bottomRight;
  }
}

/// Small draggable portrait. It waits in a corner and opens chat on tap.
class AssistantAvatar extends StatefulWidget {
  const AssistantAvatar({
    super.key,
    required this.name,
    required this.corner,
    required this.safe,
    required this.onOpen,
    required this.onCornerChanged,
    this.listening = false,
  });

  final String name;
  final AssistantCorner corner;
  final EdgeInsets safe;
  final VoidCallback onOpen;
  final ValueChanged<AssistantCorner> onCornerChanged;
  final bool listening;

  @override
  State<AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<AssistantAvatar> {
  Offset? _dragTopLeft;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final glyph = assistantGlyph(widget.name);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Size(constraints.maxWidth, constraints.maxHeight);
        final resting = AssistantAvatarGeometry.origin(
          corner: widget.corner,
          screen: screen,
          safe: widget.safe,
        );
        final topLeft = _dragTopLeft ?? resting;
        return SizedBox(
          width: screen.width,
          height: screen.height,
          child: Stack(
            children: [
              Positioned(
                left: topLeft.dx,
                top: topLeft.dy,
                child: _face(p, glyph, screen, resting),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _face(AppPalette p, String glyph, Size screen, Offset resting) {
    return Semantics(
        button: true,
        label: widget.name,
        child: GestureDetector(
          onTap: widget.onOpen,
          onPanUpdate: (details) {
            final current = _dragTopLeft ?? resting;
            setState(() {
              _dragTopLeft = AssistantAvatarGeometry.clamp(
                topLeft: current + details.delta,
                screen: screen,
                safe: widget.safe,
              );
            });
          },
          onPanEnd: (_) {
            final dropped = _dragTopLeft;
            if (dropped == null) return;
            final next = AssistantAvatarGeometry.nearest(
              topLeft: dropped,
              screen: screen,
            );
            setState(() => _dragTopLeft = null);
            if (next != widget.corner) widget.onCornerChanged(next);
          },
          child: SizedBox(
            width: AssistantAvatarGeometry.size,
            height: AssistantAvatarGeometry.size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.primary,
                shape: BoxShape.circle,
                border: Border.all(color: p.surface, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    glyph,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  if (widget.listening)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.success,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 12, height: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}
