import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import '../core/drag_model.dart';
import '../core/theme.dart';

class DragOverlay extends StatelessWidget {
  final DragState drag;
  final Rect? targetRect;
  const DragOverlay({super.key, required this.drag, required this.targetRect});
  @override
  Widget build(BuildContext context) {
    if (!drag.isDragging || targetRect == null) return const SizedBox.shrink();
    final rect = targetRect!;
    final guide = _zoneRect(rect, drag.hoverZone);
    if (guide == Rect.zero) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(children: [
        Positioned.fromRect(
          rect: guide,
          child: Container(
            decoration: BoxDecoration(
              color: IDETheme.accent.withValues(alpha: 0.25),
              border: Border.all(color: IDETheme.accent, width: 2),
            ),
          ),
        ),
      ]),
    );
  }

  Rect _zoneRect(Rect rect, DropZone zone) {
    const f = 0.5;
    switch (zone) {
      case DropZone.left:
        return Rect.fromLTWH(rect.left, rect.top, rect.width * f, rect.height);
      case DropZone.right:
        return Rect.fromLTWH(rect.left + rect.width * (1 - f), rect.top,
            rect.width * f, rect.height);
      case DropZone.top:
        return Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * f);
      case DropZone.bottom:
        return Rect.fromLTWH(rect.left, rect.top + rect.height * (1 - f),
            rect.width, rect.height * f);
      case DropZone.center:
        return Rect.fromLTWH(rect.left + rect.width * .2,
            rect.top + rect.height * .2, rect.width * .6, rect.height * .6);
      case DropZone.tabbar:
        return Rect.fromLTWH(rect.left, rect.top, rect.width, 32);
      case DropZone.none:
        return Rect.zero;
    }
  }
}
