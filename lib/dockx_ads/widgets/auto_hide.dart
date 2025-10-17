import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import '../core/drag_model.dart';
import '../core/theme.dart';

class AutoHideStrip extends StatelessWidget {
  final Map<AutoSide, List<String>> hidden;
  final String Function(String id) titleOf;
  final void Function(AutoSide side, String id) onShowFlyout;
  final void Function(AutoSide side, String id, Offset globalDown)?
      onBeginDrag; // NEW
  final void Function(Offset globalMove)? onDragUpdate; // NEW
  final VoidCallback? onDragEnd; // NEW
  final DockStyle style;

  const AutoHideStrip({
    super.key,
    required this.hidden,
    required this.titleOf,
    required this.onShowFlyout,
    this.onBeginDrag,
    this.onDragUpdate,
    this.onDragEnd,
    this.style = const DockStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final hasLeft = (hidden[AutoSide.left] ?? const []).isNotEmpty;
    final hasRight = (hidden[AutoSide.right] ?? const []).isNotEmpty;
    final hasBottom = (hidden[AutoSide.bottom] ?? const []).isNotEmpty;

    final children = <Widget>[];

    if (hasLeft) {
      children.add(Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: style.stripThickness,
        child: Container(
          decoration: BoxDecoration(
            color: style.surface2,
            border: Border(right: BorderSide(color: style.border)),
          ),
        ),
      ));
      children.add(Positioned(
        left: 0,
        top: 10,
        bottom: style.autoHideGap,
        width: style.stripThickness,
        child: _SideColumn(
          side: AutoSide.left,
          items: hidden[AutoSide.left] ?? const [],
          titleOf: titleOf,
          onTap: (id) => onShowFlyout(AutoSide.left, id),
          onBeginDrag: onBeginDrag,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          style: style,
        ),
      ));
    }

    if (hasRight) {
      children.add(Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: style.stripThickness,
        child: Container(
          decoration: BoxDecoration(
            color: style.surface2,
            border: Border(left: BorderSide(color: style.border)),
          ),
        ),
      ));
      children.add(Positioned(
        right: 0,
        top: 10,
        bottom: style.autoHideGap,
        width: style.stripThickness,
        child: _SideColumn(
          side: AutoSide.right,
          items: hidden[AutoSide.right] ?? const [],
          titleOf: titleOf,
          onTap: (id) => onShowFlyout(AutoSide.right, id),
          onBeginDrag: onBeginDrag,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          style: style,
        ),
      ));
    }

    if (hasBottom) {
      children.add(Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: style.stripThickness,
        child: Container(
          decoration: BoxDecoration(
            color: style.surface2,
            border: Border(top: BorderSide(color: style.border)),
          ),
        ),
      ));
      children.add(Positioned(
        left: 10,
        right: 10,
        bottom: 0,
        height: style.stripThickness,
        child: _BottomRow(
          items: hidden[AutoSide.bottom] ?? const [],
          titleOf: titleOf,
          onTap: (id) => onShowFlyout(AutoSide.bottom, id),
          onBeginDrag: onBeginDrag,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          style: style,
        ),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Stack(children: children);
  }
}

class _SideColumn extends StatelessWidget {
  final AutoSide side;
  final List<String> items;
  final String Function(String id) titleOf;
  final void Function(String id) onTap;
  final void Function(AutoSide side, String id, Offset globalDown)? onBeginDrag;
  final void Function(Offset globalMove)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final DockStyle style;

  const _SideColumn({
    required this.side,
    required this.items,
    required this.titleOf,
    required this.onTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final id in items)
          Padding(
            padding: const EdgeInsets.all(4),
            child: RotatedBox(
              quarterTurns: side == AutoSide.left ? 3 : 1,
              child: _DraggableStripButton(
                side: side,
                id: id,
                text: titleOf(id),
                onTap: () => onTap(id),
                onBeginDrag: onBeginDrag,
                onDragUpdate: onDragUpdate,
                onDragEnd: onDragEnd,
                style: style,
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomRow extends StatelessWidget {
  final List<String> items;
  final String Function(String id) titleOf;
  final void Function(String id) onTap;
  final void Function(AutoSide side, String id, Offset globalDown)? onBeginDrag;
  final void Function(Offset globalMove)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final DockStyle style;

  const _BottomRow({
    required this.items,
    required this.titleOf,
    required this.onTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final id in items)
          Padding(
            padding: const EdgeInsets.all(4),
            child: _DraggableStripButton(
              side: AutoSide.bottom,
              id: id,
              text: titleOf(id),
              onTap: () => onTap(id),
              onBeginDrag: onBeginDrag,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
              style: style,
            ),
          ),
      ],
    );
  }
}

class _DraggableStripButton extends StatefulWidget {
  final AutoSide side;
  final String id;
  final String text;
  final VoidCallback onTap;
  final void Function(AutoSide side, String id, Offset globalDown)? onBeginDrag;
  final void Function(Offset globalMove)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final DockStyle style;

  const _DraggableStripButton({
    required this.side,
    required this.id,
    required this.text,
    required this.onTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.style,
  });

  @override
  State<_DraggableStripButton> createState() => _DraggableStripButtonState();
}

class _DraggableStripButtonState extends State<_DraggableStripButton> {
  bool _hover = false;
  bool _dragging = false;
  Offset? _down;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (e) {
          _down = e.position;
        },
        onPointerMove: (e) {
          if (_dragging == false && _down != null) {
            if ((e.position - _down!).distance > 6) {
              _dragging = true;
              widget.onBeginDrag?.call(widget.side, widget.id, _down!);
            }
          }
          if (_dragging) {
            widget.onDragUpdate?.call(e.position);
          }
        },
        onPointerUp: (_) {
          if (_dragging) {
            widget.onDragEnd?.call();
          } else {
            widget.onTap();
          }
          _down = null;
          _dragging = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.style.stripButtonPadding,
          decoration: BoxDecoration(
            color:
                _hover ? widget.style.stripButtonHover : widget.style.surface,
            border: Border.all(color: widget.style.border),
          ),
          child: Text(
            widget.text,
            style: TextStyle(color: widget.style.text, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class AutoHideFlyout extends StatefulWidget {
  final AutoSide side;
  final String panelId;
  final String title;
  final Widget content;
  final void Function(AutoSide side, String panelId) onPin;
  final void Function() onClose;
  final void Function(Offset globalStart, String panelId) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;
  final void Function(String panelId) onRemove;
  final DockStyle style;

  const AutoHideFlyout({
    super.key,
    required this.side,
    required this.panelId,
    required this.title,
    required this.content,
    required this.onPin,
    required this.onClose,
    required this.onRemove,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.style = const DockStyle(),
  });

  @override
  State<AutoHideFlyout> createState() => _AutoHideFlyoutState();
}

class _AutoHideFlyoutState extends State<AutoHideFlyout> {
  bool _visible = false;

  // Only the resizable dimension is stored:
  //  - left/right: store width
  //  - bottom: store height
  double? _w; // used for left/right
  double? _h; // used for bottom

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  Offset _startDir() {
    switch (widget.side) {
      case AutoSide.left:
        return const Offset(-1, 0);
      case AutoSide.right:
        return const Offset(1, 0);
      case AutoSide.bottom:
        return const Offset(0, 1);
    }
  }

  void _requestClose() {
    if (!mounted) return;
    setState(() => _visible = false);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Strict 100% dimension per side
    final isVertical = widget.side != AutoSide.bottom; // left/right
    // Left/Right => height = 100%
    // Bottom     => width  = 100%

    // Clamp ranges for the resizable dimension only
    final minW = 220.0;
    final maxW = (size.width * 0.8).clamp(minW, size.width);
    final minH = 160.0;
    final maxH = (size.height * 0.8).clamp(minH, size.height);

    // Effective size:
    // - vertical: width is adjustable, height forced to full viewport
    // - bottom:   height is adjustable, width forced to full viewport
    final double w = isVertical
        ? (_w ?? 360.0).clamp(minW, maxW)
        : size.width; // 100% for bottom
    final double h = isVertical
        ? size.height // 100% for left/right
        : (_h ?? 280.0).clamp(minH, maxH);

    // Position against strips
    final left = widget.side == AutoSide.left
        ? widget.style.stripThickness
        : (widget.side == AutoSide.right
            ? size.width - w - widget.style.stripThickness
            : 0.0);
    final top = widget.side == AutoSide.bottom
        ? size.height - h - widget.style.stripThickness
        : 0.0;

    Offset? down;
    final begin = Offset(
      _startDir().dx * widget.style.flyoutAnimationOffset,
      _startDir().dy * widget.style.flyoutAnimationOffset,
    );

    // Resizers (affect only the free dimension)
    void _resizeWidth(double dx) {
      if (!isVertical) return; // bottom doesn't resize width
      final sign = (widget.side == AutoSide.left) ? 1.0 : -1.0;
      final next = (w + sign * dx).clamp(minW, maxW);
      if (next != w) setState(() => _w = next);
    }

    void _resizeHeight(double dy) {
      if (isVertical) return; // left/right don't resize height
      final sign = -1.0; // top grip: dragging up (-dy) grows
      final next = (h + sign * dy).clamp(minH, maxH);
      if (next != h) setState(() => _h = next);
    }

    final header = _FlyoutHeader(
      title: widget.title,
      style: widget.style,
      onDown: (pos) {
        down = pos;
        widget.onDragStart(pos, widget.panelId);
      },
      onMove: (pos) {
        if (down != null) widget.onDragUpdate(pos);
      },
      onUp: () {
        down = null;
        widget.onDragEnd();
      },
      onPin: () => widget.onPin(widget.side, widget.panelId),
      onRemove: () => widget.onRemove(widget.panelId),
    );

    final body = Container(
      decoration: BoxDecoration(
        color: widget.style.surface,
        border: Border.all(color: widget.style.border),
      ),
      child: Column(
        children: [
          header,
          Expanded(
            child: Container(
              color: widget.style.background,
              child: widget.content,
            ),
          ),
        ],
      ),
    );

    // Grips
    final grips = <Widget>[];
    if (widget.side == AutoSide.left) {
      grips.add(Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 6,
        child: _SideResizeBar(onDragDeltaX: _resizeWidth, style: widget.style),
      ));
    } else if (widget.side == AutoSide.right) {
      grips.add(Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 6,
        child: _SideResizeBar(onDragDeltaX: _resizeWidth, style: widget.style),
      ));
    } else if (widget.side == AutoSide.bottom) {
      grips.add(Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 6,
        child: _TopResizeBar(onDragDeltaY: _resizeHeight, style: widget.style),
      ));
    }

    return Stack(children: [
      // click outside to close
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _requestClose,
          child: Container(color: const Color(0x00000000)),
        ),
      ),
      AnimatedPositioned(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        left: left,
        top: top,
        width: w,
        height: h,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween<Offset>(
            begin: _visible ? Offset.zero : begin,
            end: _visible ? Offset.zero : begin,
          ),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, offset, child) =>
              Transform.translate(offset: offset, child: child),
          child: Stack(children: [body, ...grips]),
        ),
      ),
    ]);
  }
}

// ======= header and grips (unchanged, theme-aware) =================

class _FlyoutHeader extends StatelessWidget {
  final String title;
  final DockStyle style;
  final void Function(Offset pos) onDown;
  final void Function(Offset pos) onMove;
  final VoidCallback onUp;
  final VoidCallback onPin;
  final VoidCallback onRemove;
  const _FlyoutHeader({
    required this.title,
    required this.style,
    required this.onDown,
    required this.onMove,
    required this.onUp,
    required this.onPin,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Offset? down;
    return Listener(
      onPointerDown: (e) {
        down = e.position;
        onDown(e.position);
      },
      onPointerMove: (e) {
        if (down != null) onMove(e.position);
      },
      onPointerUp: (_) {
        down = null;
        onUp();
      },
      child: Container(
        height: 28,
        color: style.surface,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: style.text, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(style.iconPin, size: 12, color: style.text),
              onPressed: onPin,
            ),
            IconButton(
              icon: Icon(style.iconClose, size: 12, color: style.text),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideResizeBar extends StatefulWidget {
  final void Function(double dx) onDragDeltaX;
  final DockStyle style;
  const _SideResizeBar({required this.onDragDeltaX, required this.style});
  @override
  State<_SideResizeBar> createState() => _SideResizeBarState();
}

class _SideResizeBarState extends State<_SideResizeBar> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerMove: (e) => widget.onDragDeltaX(e.delta.dx),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hover ? widget.style.surface2 : const Color(0x00000000),
            border: Border(left: BorderSide(color: widget.style.border)),
          ),
        ),
      ),
    );
  }
}

class _TopResizeBar extends StatefulWidget {
  final void Function(double dy) onDragDeltaY;
  final DockStyle style;
  const _TopResizeBar({required this.onDragDeltaY, required this.style});
  @override
  State<_TopResizeBar> createState() => _TopResizeBarState();
}

class _TopResizeBarState extends State<_TopResizeBar> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerMove: (e) => widget.onDragDeltaY(e.delta.dy),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hover ? widget.style.surface2 : const Color(0x00000000),
            border: Border(bottom: BorderSide(color: widget.style.border)),
          ),
        ),
      ),
    );
  }
}
