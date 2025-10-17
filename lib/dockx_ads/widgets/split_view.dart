import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';

class SplitView extends StatefulWidget {
  final SplitNode node;
  final Widget aBuilder;
  final Widget bBuilder;

  /// Theme (provides splitter colors). Defaults keep backward compatibility.
  final DockStyle style;

  /// Minimum fraction for each side (0.0–0.5).
  final double minFraction;

  /// Thickness of the draggable splitter handle (and the highlight) in px.
  final double handleThickness;

  const SplitView({
    super.key,
    required this.node,
    required this.aBuilder,
    required this.bBuilder,
    this.style = const DockStyle(),
    this.minFraction = 0.10,
    this.handleThickness = 8.0,
  });

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView> {
  bool get _isH => widget.node.axis == SplitAxis.horizontal;

  // Frozen drag baseline to avoid bounce while dragging.
  double _startRatio = 0.5;
  double _startAvail = 1.0;
  double _accumDelta = 0.0;
  bool _dragging = false;

  // Hover state for handle (to show highlight on hover).
  bool _hovering = false;

  // Tiny hysteresis to avoid floating-point jitter.
  static const double _eps = 0.0005;

  @override
  Widget build(BuildContext context) {
    widget.node.ratio = widget.node.ratio.clamp(0.0, 1.0);

    // Get highlight color from theme; fallbacks keep things safe.
    final Color hlColor =
        (widget.style.splitterHighlight).withOpacity(_dragging ? 0.60 : 1);

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth;
        final maxH = c.maxHeight;

        if (maxW.isInfinite || maxH.isInfinite) {
          return SizedBox.expand(
            child: _isH
                ? Row(children: [
                    Expanded(child: widget.aBuilder),
                    Expanded(child: widget.bBuilder)
                  ])
                : Column(children: [
                    Expanded(child: widget.aBuilder),
                    Expanded(child: widget.bBuilder)
                  ]),
          );
        }

        final handle = widget.handleThickness;
        final min = widget.minFraction.clamp(0.0, 0.5);
        final avail = _isH ? (maxW - handle) : (maxH - handle);

        final minRatio = min;
        final maxRatio = 1.0 - min;

        double ratio;
        if (_dragging) {
          final newRatio = (_startRatio + (_accumDelta / _startAvail))
              .clamp(minRatio, maxRatio);
          if ((newRatio - widget.node.ratio).abs() > _eps) {
            widget.node.ratio = newRatio;
          }
          ratio = widget.node.ratio;
        } else {
          ratio = widget.node.ratio.clamp(minRatio, maxRatio);
        }

        final aMain = avail * ratio;
        final bMain = avail - aMain;

        final showHighlight = _hovering || _dragging;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Pane A
            Positioned(
              left: 0,
              top: 0,
              width: _isH ? aMain : maxW,
              height: _isH ? maxH : aMain,
              child: widget.aBuilder,
            ),

            // HIGHLIGHT (exact same rect as the handle)
            if (showHighlight)
              Positioned(
                left: _isH ? aMain : 0,
                top: _isH ? 0 : aMain,
                width: _isH ? handle : maxW,
                height: _isH ? maxH : handle,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 80),
                    opacity: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: hlColor),
                    ),
                  ),
                ),
              ),

            // HANDLE (same rect as highlight)
            Positioned(
              left: _isH ? aMain : 0,
              top: _isH ? 0 : aMain,
              width: _isH ? handle : maxW,
              height: _isH ? maxH : handle,
              child: _DragHandle(
                horizontal: _isH,
                onHover: (h) {
                  if (_hovering == h) return;
                  setState(() => _hovering = h);
                },
                onStart: () {
                  _dragging = true;
                  _accumDelta = 0.0;
                  _startRatio = ratio;
                  _startAvail = avail; // freeze baseline to prevent bounce
                  setState(() {});
                },
                onUpdateDelta: (delta) {
                  _accumDelta +=
                      delta; // accumulate delta; ratio recomputed from frozen baseline
                  setState(() {});
                },
                onEnd: () {
                  _dragging = false;
                  _accumDelta = 0.0;
                  setState(() {});
                },
              ),
            ),

            // Pane B
            Positioned(
              left: _isH ? (aMain + handle) : 0,
              top: _isH ? 0 : (aMain + handle),
              width: _isH ? bMain : maxW,
              height: _isH ? maxH : bMain,
              child: widget.bBuilder,
            ),
          ],
        );
      },
    );
  }
}

class _DragHandle extends StatelessWidget {
  final bool horizontal; // true => drag left/right
  final void Function(bool hover) onHover;
  final VoidCallback onStart;
  final void Function(double delta) onUpdateDelta;
  final VoidCallback onEnd;

  const _DragHandle({
    required this.horizontal,
    required this.onHover,
    required this.onStart,
    required this.onUpdateDelta,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final cursor = horizontal
        ? SystemMouseCursors.resizeColumn
        : SystemMouseCursors.resizeRow;

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: horizontal ? (_) => onStart() : null,
        onHorizontalDragUpdate:
            horizontal ? (d) => onUpdateDelta(d.primaryDelta ?? 0) : null,
        onHorizontalDragEnd: horizontal ? (_) => onEnd() : null,
        onVerticalDragStart: horizontal ? null : (_) => onStart(),
        onVerticalDragUpdate:
            horizontal ? null : (d) => onUpdateDelta(d.primaryDelta ?? 0),
        onVerticalDragEnd: horizontal ? null : (_) => onEnd(),
      ),
    );
  }
}
