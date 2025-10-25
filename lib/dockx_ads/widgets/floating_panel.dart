import 'package:fluent_ui/fluent_ui.dart';
import '../core/theme.dart';

typedef FloatDragStart = void Function(Offset globalDown, Offset grabOffset);
typedef FloatDragUpdate = void Function(Offset globalMove);
typedef FloatDragEnd = void Function();
typedef FloatResize = void Function(Size newSize);

class FloatTitleBar extends StatefulWidget {
  final String title;
  final DockStyle style;
  final double height;
  final void Function(Offset globalDown, Offset localDown) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onClose;
  const FloatTitleBar({
    required this.title,
    required this.style,
    required this.height,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onClose,
    super.key,
  });

  @override
  State<FloatTitleBar> createState() => _FloatTitleBarState();
}

class _FloatTitleBarState extends State<FloatTitleBar> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _dragging = true;
        widget.onDragStart(d.globalPosition, d.localPosition); // global + local
      },
      onPanUpdate: (d) {
        if (_dragging) widget.onDragUpdate(d.globalPosition); // absolute global
      },
      onPanEnd: (_) {
        if (_dragging) {
          _dragging = false;
          widget.onDragEnd();
        }
      },
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.style.surface2,
          border: Border(bottom: BorderSide(color: widget.style.border)),
        ),
        child: Row(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 10),
              onPressed: widget.onClose,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(widget.style.surface),
                padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatefulWidget {
  final String title;
  final DockStyle style;
  final double height;
  final void Function(Offset localDown) onDragStart;
  final void Function(Offset localMove) onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onClose;
  const _TitleBar({
    required this.title,
    required this.style,
    required this.height,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onClose,
  });

  @override
  State<_TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<_TitleBar> {
  Offset _down = Offset.zero;
  bool _drag = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _down = d.localPosition;
        _drag = true;
        widget.onDragStart(_down);
      },
      onPanUpdate: (d) {
        if (!_drag) return;
        _down += d.delta;
        widget.onDragUpdate(_down);
      },
      onPanEnd: (_) {
        if (!_drag) return;
        _drag = false;
        widget.onDragEnd();
      },
      child: Container(
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.style.surface2,
          border: Border(bottom: BorderSide(color: widget.style.border)),
        ),
        child: Row(
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 10),
              onPressed: widget.onClose,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(widget.style.surface),
                padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
