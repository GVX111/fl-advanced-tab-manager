import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
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
    required this.style,
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

  /// Ratios of the splits nested on both sides when the drag started: each
  /// move is computed from them, so dragging back restores the neighbours
  /// a move had squeezed.
  List<(SplitNode, double)> _nestedAtStart = const [];

  static List<(SplitNode, double)> _snapshot(DockNode n) => switch (n) {
        SplitNode s => [(s, s.ratio), ..._snapshot(s.a), ..._snapshot(s.b)],
        _ => const [],
      };

  // Hover state for handle (to show highlight on hover).
  bool _hovering = false;

  // Tiny hysteresis to avoid floating-point jitter.
  static const double _eps = 0.0005;

  @override
  Widget build(BuildContext context) {
    widget.node.ratio = widget.node.ratio.clamp(0.0, 1.0);

    // Get highlight color from theme; fallbacks keep things safe.
    final Color hlColor = (widget.style.splitterHighlight)
        .withValues(alpha: _dragging ? 0.60 : 1);

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
        // Each side never gets smaller than its containers' minimum size
        // (in pixels, counting the containers nested in it).
        final minPx = _isH ? widget.style.minPanelWidth : widget.style.minPanelHeight;
        final minA = minExtent(widget.node.a, widget.node.axis, minPx, handle);
        final minB = minExtent(widget.node.b, widget.node.axis, minPx, handle);
        final avail = _isH ? (maxW - handle) : (maxH - handle);

        // Pixel minimums when they fit; else the old fractions.
        final fits = avail > 0 && minA + minB <= avail;
        final minRatio = fits ? minA / avail : min;
        final maxRatio = fits ? 1.0 - minB / avail : 1.0 - min;

        double ratio;
        if (_dragging) {
          final newRatio = (_startRatio + (_accumDelta / _startAvail))
              .clamp(minRatio, maxRatio);
          if ((newRatio - widget.node.ratio).abs() > _eps) {
            // Only the panes next to the divider change size: panes further
            // away inside nested splits keep their size in pixels. Always
            // from the state at the start of the drag.
            for (final (s, r) in _nestedAtStart) {
              s.ratio = r;
            }
            final oldA = _startAvail * _startRatio, newA = avail * newRatio;
            keepFarPanes(widget.node.a, widget.node.axis, oldA, newA,
                farIsA: true, handle: handle, minPx: minPx);
            keepFarPanes(widget.node.b, widget.node.axis, _startAvail - oldA,
                avail - newA,
                farIsA: false, handle: handle, minPx: minPx);
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
            // Keys: the highlight comes and goes before the handle; without
            // them the handle (and a drag in progress) would be rebuilt.
            // Pane A
            Positioned(
              key: const ValueKey('pane-a'),
              left: 0,
              top: 0,
              width: _isH ? aMain : maxW,
              height: _isH ? maxH : aMain,
              child: widget.aBuilder,
            ),

            // HIGHLIGHT (exact same rect as the handle)
            if (showHighlight)
              Positioned(
                key: const ValueKey('highlight'),
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
              key: const ValueKey('handle'),
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
                  _nestedAtStart = [
                    ..._snapshot(widget.node.a),
                    ..._snapshot(widget.node.b),
                  ];
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
              key: const ValueKey('pane-b'),
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

/// [node] (one side of a split being resized) goes from [oldMain] to
/// [newMain] pixels along [axis]. When it is itself split along the same
/// axis, its ratio is adjusted so the pane away from the moved divider
/// ([farIsA]: the first pane) keeps its size, and the change goes to the
/// pane next to the divider (recursively).
void keepFarPanes(
  DockNode node,
  SplitAxis axis,
  double oldMain,
  double newMain, {
  required bool farIsA,
  required double handle,
  required double minPx,
}) {
  if (node is! SplitNode || node.axis != axis) return;
  final oldAvail = oldMain - handle, newAvail = newMain - handle;
  if (oldAvail <= 0 || newAvail <= 0) return;
  final r = node.ratio.clamp(0.0, 1.0);
  final far = oldAvail * (farIsA ? r : 1 - r);
  // The far pane keeps its size, unless the near one would go below its
  // minimum; then the far one gives way (down to its own minimum).
  final minFar = minExtent(farIsA ? node.a : node.b, axis, minPx, handle);
  final minNear = minExtent(farIsA ? node.b : node.a, axis, minPx, handle);
  final lo = (minFar / newAvail).clamp(0.0, 1.0);
  final hi = (1.0 - minNear / newAvail).clamp(0.0, 1.0);
  final farFraction = lo <= hi
      ? (far / newAvail).clamp(lo, hi).toDouble()
      : (far / newAvail).clamp(0.0, 1.0).toDouble();
  final newRatio = farIsA ? farFraction : 1 - farFraction;
  final oldNear = oldAvail * (farIsA ? 1 - r : r);
  final newNear = newAvail * (farIsA ? 1 - newRatio : newRatio);
  node.ratio = newRatio;
  keepFarPanes(farIsA ? node.b : node.a, axis, oldNear, newNear,
      farIsA: farIsA, handle: handle, minPx: minPx);
}

/// Smallest size of [node] along [axis]: [minPx] per container, plus the
/// splitters between containers placed along that axis.
double minExtent(DockNode node, SplitAxis axis, double minPx, double handle) {
  if (node is SplitNode) {
    final a = minExtent(node.a, axis, minPx, handle);
    final b = minExtent(node.b, axis, minPx, handle);
    return node.axis == axis ? a + b + handle : (a > b ? a : b);
  }
  return minPx;
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
