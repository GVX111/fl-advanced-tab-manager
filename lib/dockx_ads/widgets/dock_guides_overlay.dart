import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../core/models.dart';
import '../core/theme.dart';

class DockGuidesOverlay extends StatelessWidget {
  final Rect? targetRect;
  final DropZone hoverZone;
  final DockStyle style;

  const DockGuidesOverlay({
    super.key,
    required this.targetRect,
    required this.hoverZone,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (targetRect == null) return const SizedBox.shrink();
    final r = targetRect!;
    final double s = 28; // guide button size
    final double pad = 8;

    Widget btn(DropZone z, IconData icon, Offset c) {
      final sel = z == hoverZone;
      return Positioned(
        left: c.dx - s / 2,
        top: c.dy - s / 2,
        width: s,
        height: s,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sel
                ? (style.accent ?? const Color(0xFF0078D4)).withOpacity(.95)
                : style.surface2.withOpacity(.85),
            border: Border.all(color: style.border, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 12, color: const Color(0xFFFFFFFF)),
        ),
      );
    }

    final cx = r.left + r.width / 2;
    final cy = r.top + r.height / 2;

    return IgnorePointer(
      child: Stack(children: [
        btn(DropZone.left, FluentIcons.caret_left_solid8,
            Offset(r.left - s - pad, cy)),
        btn(DropZone.right, FluentIcons.caret_right_solid8,
            Offset(r.right + s + pad, cy)),
        btn(DropZone.top, FluentIcons.caret_up_solid8,
            Offset(cx, r.top - s - pad)),
        btn(DropZone.bottom, FluentIcons.caret_down_solid8,
            Offset(cx, r.bottom + s + pad)),
        btn(DropZone.center, FluentIcons.page, Offset(cx, cy)),
      ]),
    );
  }
}
