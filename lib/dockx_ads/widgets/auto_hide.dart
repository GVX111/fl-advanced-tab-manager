import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import '../core/drag_model.dart';
import '../core/theme.dart';

class AutoHideStrip extends StatelessWidget {
  final Map<AutoSide, List<String>> hidden;
  final String Function(String id) titleOf;
  final void Function(AutoSide side, String id) onShowFlyout;
  final DockStyle style;

  const AutoHideStrip(
      {super.key,
      required this.hidden,
      required this.titleOf,
      required this.onShowFlyout,
      this.style = const DockStyle()});

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
            style: style),
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
            style: style),
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
            style: style),
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
  final DockStyle style;
  const _SideColumn(
      {required this.side,
      required this.items,
      required this.titleOf,
      required this.onTap,
      required this.style});

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
              child: _StripButton(
                  text: titleOf(id), onTap: () => onTap(id), style: style),
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
  final DockStyle style;
  const _BottomRow(
      {required this.items,
      required this.titleOf,
      required this.onTap,
      required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        for (final id in items)
          Padding(
            padding: const EdgeInsets.all(4),
            child: _StripButton(
                text: titleOf(id), onTap: () => onTap(id), style: style),
          ),
      ],
    );
  }
}

class _StripButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final DockStyle style;
  const _StripButton(
      {required this.text, required this.onTap, required this.style});
  @override
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.style.stripButtonPadding,
          decoration: BoxDecoration(
            color:
                _hover ? widget.style.stripButtonHover : widget.style.surface,
            border: Border.all(color: widget.style.border),
          ),
          child: Text(widget.text,
              style: TextStyle(color: widget.style.text, fontSize: 12)),
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
  final void Function(Offset globalStart) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;
  final DockStyle style;

  const AutoHideFlyout({
    super.key,
    required this.side,
    required this.panelId,
    required this.title,
    required this.content,
    required this.onPin,
    required this.onClose,
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
    final bool vertical = widget.side != AutoSide.bottom;
    final w = vertical ? 360.0 : size.width;
    final h = vertical ? size.height : 280.0;

    final left = widget.side == AutoSide.left
        ? widget.style.stripThickness
        : (widget.side == AutoSide.right
            ? size.width - w - widget.style.stripThickness
            : 0.0);
    final top = widget.side == AutoSide.bottom
        ? size.height - h - widget.style.stripThickness
        : 0.0;

    Offset? down;
    final begin = Offset(_startDir().dx * widget.style.flyoutAnimationOffset,
        _startDir().dy * widget.style.flyoutAnimationOffset);

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
            onTap: _requestClose,
            child: Container(color: const Color(0x00000000))),
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
              end: _visible ? Offset.zero : begin),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, offset, child) =>
              Transform.translate(offset: offset, child: child),
          child: Container(
            decoration: BoxDecoration(
                color: widget.style.surface,
                border: Border.all(color: widget.style.border)),
            child: Column(children: [
              Listener(
                onPointerDown: (e) {
                  down = e.position;
                  widget.onDragStart(e.position);
                },
                onPointerMove: (e) {
                  if (down != null) widget.onDragUpdate(e.position);
                },
                onPointerUp: (_) {
                  down = null;
                  widget.onDragEnd();
                },
                child: Container(
                  height: 28,
                  color: widget.style.surface,
                  child: Row(children: [
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(widget.title,
                            style: TextStyle(
                                color: widget.style.text, fontSize: 12))),
                    IconButton(
                        icon: Icon(widget.style.iconPin,
                            size: 12, color: widget.style.text),
                        onPressed: () {
                          widget.onPin(widget.side, widget.panelId);
                        }),
                    IconButton(
                        icon: Icon(widget.style.iconClose,
                            size: 12, color: widget.style.text),
                        onPressed: _requestClose),
                  ]),
                ),
              ),
              Expanded(
                  child: Container(
                      color: widget.style.background, child: widget.content)),
            ]),
          ),
        ),
      ),
    ]);
  }
}
