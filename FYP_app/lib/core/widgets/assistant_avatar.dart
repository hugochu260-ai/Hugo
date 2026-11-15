import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'assistant_portrait.dart';

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
  static const double width = 84;
  static const double height = 96;
  static const double margin = 12;
  static const double portrait = 72;

  static Offset origin({
    required AssistantCorner corner,
    required Size screen,
    required EdgeInsets safe,
  }) {
    final left = safe.left + margin;
    final top = safe.top + margin;
    final right = math.max(left, screen.width - safe.right - width - margin);
    final bottom = math.max(top, screen.height - safe.bottom - height - margin);
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
    final maxX = math.max(minX, screen.width - safe.right - width - margin);
    final maxY = math.max(minY, screen.height - safe.bottom - height - margin);
    return Offset(
      topLeft.dx.clamp(minX, maxX),
      topLeft.dy.clamp(minY, maxY),
    );
  }

  static AssistantCorner nearest({
    required Offset topLeft,
    required Size screen,
  }) {
    final center = topLeft + const Offset(width / 2, height / 2);
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
    this.onLongPress,
    this.imagePath = '',
    this.listening = false,
  });

  final String name;
  final AssistantCorner corner;
  final EdgeInsets safe;
  final VoidCallback onOpen;
  final ValueChanged<AssistantCorner> onCornerChanged;
  final VoidCallback? onLongPress;
  final String imagePath;
  final bool listening;

  @override
  State<AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<AssistantAvatar> {
  Offset? _dragTopLeft;

  @override
  Widget build(BuildContext context) {
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
                child: _face(screen, resting),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _face(Size screen, Offset resting) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: widget.name,
      child: GestureDetector(
        onTap: widget.onOpen,
        onLongPress: widget.onLongPress,
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
          width: AssistantAvatarGeometry.width,
          height: AssistantAvatarGeometry.height,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: AssistantAvatarGeometry.portrait,
                height: AssistantAvatarGeometry.portrait,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surface,
                  border: Border.all(color: p.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AssistantPortrait(imagePath: widget.imagePath),
              ),
              if (widget.listening)
                Positioned(
                  right: 8,
                  top: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surface, width: 2),
                    ),
                    child: const SizedBox(width: 12, height: 12),
                  ),
                ),
              Positioned(
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
