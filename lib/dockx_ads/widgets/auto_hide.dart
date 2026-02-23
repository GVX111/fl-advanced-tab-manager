import 'package:fluent_ui/fluent_ui.dart';
import '../core/drag_model.dart';
import '../core/theme.dart';

class AutoHideStrip extends StatelessWidget {
  final Map<AutoSide, List<String>> hidden;
  final String Function(String id) titleOf;
  final void Function(AutoSide side, String id) onShowFlyout;
  final void Function(AutoSide side, String id, Offset globalDown)? onBeginDrag;
  final void Function(Offset globalMove)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final DockStyle style;
  final AutoSide? activeSide;
  final String? activeId;
  const AutoHideStrip(
      {super.key,
      required this.hidden,
      required this.titleOf,
      required this.onShowFlyout,
      this.onBeginDrag,
      this.onDragUpdate,
      this.onDragEnd,
      this.activeSide,
      this.activeId,
      required this.style});

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
        top: 0,
        bottom: style.autoHideGap,
        width: style.stripThickness,
        child: _SideColumn(
          side: AutoSide.left,
          items: hidden[AutoSide.left] ?? const [],
          titleOf: titleOf,
          onTap: (id) => onShowFlyout(AutoSide.left, id),
          isActive: (id) => activeSide == AutoSide.left && activeId == id,
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
        top: 0,
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
            isActive: (id) => activeSide == AutoSide.right && activeId == id),
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
          isActive: (id) => activeSide == AutoSide.bottom && activeId == id,
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
  final bool Function(String id) isActive;
  const _SideColumn({
    required this.side,
    required this.items,
    required this.titleOf,
    required this.onTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.isActive,
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
                active: isActive(id),
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
  final bool Function(String id) isActive;
  final VoidCallback? onDragEnd;
  final DockStyle style;

  const _BottomRow(
      {required this.items,
      required this.titleOf,
      required this.onTap,
      required this.onBeginDrag,
      required this.onDragUpdate,
      required this.onDragEnd,
      required this.style,
      required this.isActive});

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
              active: isActive(id), // <-- NEW
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
  final bool active;

  const _DraggableStripButton({
    required this.side,
    required this.id,
    required this.text,
    required this.onTap,
    required this.onBeginDrag,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.style,
    this.active = false,
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
    final bool highlight =
        _hover || widget.active; // treat active same as hover
    final borderTopColor =
        highlight ? (widget.style.accent) : widget.style.border;
    final bgColor =
        highlight ? widget.style.stripButtonHover : widget.style.surface;
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
            color: bgColor,
            border: Border(
              top: BorderSide(color: borderTopColor, width: 2),
              left: BorderSide(color: widget.style.border),
              right: BorderSide(color: widget.style.border),
              bottom: BorderSide(color: widget.style.border),
            ),
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
    required this.style,
  });

  @override
  State<AutoHideFlyout> createState() => _AutoHideFlyoutState();
}

class _AutoHideFlyoutState extends State<AutoHideFlyout>
    with SingleTickerProviderStateMixin {
  // Only the resizable dimension is stored:
  //  - left/right: store width
  //  - bottom: store height
  double? _w; // used for left/right
  double? _h; // used for bottom

  late final AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 180),
    );

    _fade = CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic);

    _rebuildSlide(); // based on side
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant AutoHideFlyout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.side != widget.side) {
      _rebuildSlide();
    }
  }

  void _rebuildSlide() {
    // slide in from the side (fraction of its own size)
    final begin = switch (widget.side) {
      AutoSide.left => const Offset(-0.08, 0),
      AutoSide.right => const Offset(0.08, 0),
      AutoSide.bottom => const Offset(0, 0.10),
    };
    _slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic),
    );
    // no setState needed; transition reads animation
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _requestClose() async {
    if (_closing) return;
    _closing = true;

    await _ctrl.reverse(); // ✅ wait for animation to finish
    if (!mounted) return;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final isVertical = widget.side != AutoSide.bottom; // left/right
    final minW = 220.0;
    final maxW = (size.width * 0.8).clamp(minW, size.width);
    final minH = 160.0;
    final maxH = (size.height * 0.8).clamp(minH, size.height);

    final double w = isVertical ? (_w ?? 360.0).clamp(minW, maxW) : size.width;
    final double h = isVertical ? size.height : (_h ?? 280.0).clamp(minH, maxH);

    final left = widget.side == AutoSide.left
        ? widget.style.stripThickness
        : (widget.side == AutoSide.right
            ? size.width - w - widget.style.stripThickness
            : 0.0);
    final top = widget.side == AutoSide.bottom
        ? size.height - h - widget.style.stripThickness
        : 0.0;

    // Resizers (affect only the free dimension)
    void _resizeWidth(double dx) {
      if (!isVertical) return;
      final sign = (widget.side == AutoSide.left) ? 1.0 : -1.0;
      final next = (w + sign * dx).clamp(minW, maxW);
      if (next != w) setState(() => _w = next);
    }

    void _resizeHeight(double dy) {
      if (isVertical) return;
      final next = (h - dy).clamp(minH, maxH); // dragging up (-dy) grows
      if (next != h) setState(() => _h = next);
    }

    Offset? down;
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

    final grips = <Widget>[
      if (widget.side == AutoSide.left)
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 6,
          child:
              _SideResizeBar(onDragDeltaX: _resizeWidth, style: widget.style),
        ),
      if (widget.side == AutoSide.right)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 6,
          child:
              _SideResizeBar(onDragDeltaX: _resizeWidth, style: widget.style),
        ),
      if (widget.side == AutoSide.bottom)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 6,
          child:
              _TopResizeBar(onDragDeltaY: _resizeHeight, style: widget.style),
        ),
    ];

    return Stack(
      children: [
        // ✅ Positioned.fill must be direct Stack child
        Positioned.fill(
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _requestClose,
              child: Container(color: const Color(0x00000000)),
            ),
          ),
        ),

        // ✅ Positioned must be direct Stack child
        Positioned(
          left: left,
          top: top,
          width: w,
          height: h,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Stack(children: [body, ...grips]),
            ),
          ),
        ),
      ],
    );
  }
}
// ======= header and grips (unchanged, theme-aware) =================

class _FlyoutHeader extends StatefulWidget {
  final String title;
  final DockStyle style;
  final void Function(Offset pos) onDown; // called once when drag really begins
  final void Function(Offset pos) onMove; // continuous while dragging
  final VoidCallback onUp; // when drag ends
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
  State<_FlyoutHeader> createState() => _FlyoutHeaderState();
}

class _FlyoutHeaderState extends State<_FlyoutHeader> {
  static const _dragThreshold = 6.0;

  Offset? _downGlobal;
  bool _dragging = false;

  // Guard so buttons don’t start a drag
  bool _pointerIsOverButton = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _downGlobal = e.position;
        _dragging = false;
        _pointerIsOverButton = false; // will be set by button MouseRegions
      },
      onPointerMove: (e) {
        if (_downGlobal == null || _pointerIsOverButton) return;

        if (!_dragging) {
          // Don’t start a drag until threshold is exceeded
          if ((e.position - _downGlobal!).distance > _dragThreshold) {
            _dragging = true;
            widget.onDown(_downGlobal!); // begin drag (report initial pos)
          }
        }
        if (_dragging) {
          widget.onMove(e.position); // live drag updates
        }
      },
      onPointerUp: (_) {
        if (_dragging) {
          widget.onUp(); // finish drag
        }
        _downGlobal = null;
        _dragging = false;
        _pointerIsOverButton = false;
      },
      child: Container(
        height: 28,
        color: widget.style.surface,
        child: Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(color: widget.style.text, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Pin button – protect from starting a drag
            MouseRegion(
              onEnter: (_) => _pointerIsOverButton = true,
              onExit: (_) => _pointerIsOverButton = false,
              child: IconButton(
                icon: Icon(widget.style.iconPin,
                    size: 12, color: widget.style.text),
                onPressed: widget.onPin,
              ),
            ),

            // Close/Remove – protect from starting a drag
            MouseRegion(
              onEnter: (_) => _pointerIsOverButton = true,
              onExit: (_) => _pointerIsOverButton = false,
              child: IconButton(
                icon: Icon(widget.style.iconClose,
                    size: 12, color: widget.style.text),
                onPressed: widget.onRemove,
              ),
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
