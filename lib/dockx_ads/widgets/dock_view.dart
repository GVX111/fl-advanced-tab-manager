import 'dart:convert';
import 'package:dockx_ads_v040/dockx_ads/widgets/floating_panel.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/widgets.dart';
import '../core/models.dart';
import '../core/drag_model.dart';
import '../core/theme.dart';
import 'split_view.dart';
import 'tabs.dart';
import 'drag_overlay.dart';
import 'auto_hide.dart';

/// ---- Floating panels host ----
class _FloatWin {
  String panelId;
  Offset pos; // global top-left
  Size size;
  _FloatWin({required this.panelId, required this.pos, required this.size});
}

class DockAds extends StatefulWidget {
  DockLayout layout;
  final DockStyle style;
  DockAds({super.key, required this.layout, this.style = const DockStyle()});

  @override
  State<DockAds> createState() => _DockAdsState();
}

class _DockAdsState extends State<DockAds> {
  final DragState _drag = DragState();
  final Map<GlobalKey, ContainerNode> _containerByKey = {};
  final Map<AutoSide, List<String>> _autoHidden = {
    AutoSide.left: [],
    AutoSide.right: [],
    AutoSide.bottom: [],
  };

  AutoSide? _flySide;
  String? _flyPanelId;

  // floating windows
  final List<_FloatWin> _floats = <_FloatWin>[];
  int? _dragFloatIndex;
  Offset _dragFloatGrabOffset = Offset.zero;

  String exportPerspective() => jsonEncode(widget.layout.toJson());
  void importPerspective(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() =>
          widget.layout = DockLayout.fromJson(map, widget.layout.registry));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hasLeft = (_autoHidden[AutoSide.left] ?? const []).isNotEmpty;
    final hasRight = (_autoHidden[AutoSide.right] ?? const []).isNotEmpty;
    final hasBottom = (_autoHidden[AutoSide.bottom] ?? const []).isNotEmpty;

    final content = Stack(
      fit: StackFit.expand,
      children: [
        AutoHideStrip(
          hidden: _autoHidden,
          titleOf: (id) => widget.layout.registry.getById(id).title,
          onShowFlyout: (side, id) {
            if (!mounted) return;
            setState(() {
              _flySide = side;
              _flyPanelId = id;
            });
          },
          style: widget.style,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: hasLeft ? widget.style.stripThickness : 0,
            right: hasRight ? widget.style.stripThickness : 0,
            bottom: hasBottom ? widget.style.stripThickness : 0,
            top: 0,
          ),
          child: _buildNode(widget.layout.root),
        ),

        // Auto-hide flyout (with reliable onPin args: side, id)
        if (_flySide != null && _flyPanelId != null)
          Positioned.fill(
            bottom: hasBottom ? widget.style.stripThickness : 0,
            top: 0,
            child: AutoHideFlyout(
              side: _flySide!,
              panelId: _flyPanelId!,
              title: widget.layout.registry.getById(_flyPanelId!).title,
              content: _buildPanelContent(_flyPanelId!),
              onPin: (side, id) {
                // choose target side from DockPanelSpec.position
                final DockSide declared =
                    widget.layout.registry.getById(id).position;
                final DockSide targetSide = declared;

                // remove+insert
                _removePanelEverywhere(widget.layout.root, id);
                final bucket =
                    _findFirstContainerBySide(widget.layout.root, targetSide);
                if (bucket != null) {
                  bucket.panelIds.add(id);
                  bucket.activeIndex = bucket.panelIds.length - 1;
                } else {
                  _dockToEdge(id, targetSide);
                }

                if (!mounted) return;
                setState(() {
                  _autoHidden[side]?.remove(id);
                  _flySide = null;
                  _flyPanelId = null;
                  _simplifyTree();
                });
              },
              onClose: () {
                if (!mounted) return;
                setState(() {
                  _flySide = null;
                  _flyPanelId = null;
                });
              },
              onDragStart: (g) {
                _drag.isDragging = true;
                _drag.draggingPanelId = _flyPanelId;
              },
              onDragUpdate: (g) {
                _updateHover(g);
              },
              onDragEnd: () {
                if (_drag.targetKey != null &&
                    _drag.hoverZone != DropZone.none &&
                    _drag.draggingPanelId != null) {
                  final target = _containerByKey[_drag.targetKey]!;
                  setState(() {
                    _autoHidden[_flySide!]!.remove(_drag.draggingPanelId);
                    _dockInto(target, _drag.hoverZone, _drag.draggingPanelId!);
                    _simplifyTree();
                  });
                }
                setState(() {
                  _flySide = null;
                  _flyPanelId = null;
                });
                _resetDrag();
              },
              style: widget.style,
            ),
          ),

        // Dock guides when dragging a floating window (cross + edges)
        if (_dragFloatIndex != null)
          _DockGuidesOverlay(
            targetRect: _currentTargetRect(),
            hoverZone: _drag.hoverZone,
            style: widget.style,
          ),

        // Floating windows on top
        ...List.generate(_floats.length, (i) {
          final f = _floats[i];
          return _FloatingPanel(
            key: ValueKey('float_${f.panelId}_$i'),
            panelId: f.panelId,
            title: widget.layout.registry.getById(f.panelId).title,
            content: _buildPanelContent(f.panelId),
            pos: f.pos,
            size: f.size,
            style: widget.style,
            onDragStart: (globalDown, grabOffset) {
              setState(() {
                _dragFloatIndex = i;
                _dragFloatGrabOffset = grabOffset;
                _drag.isDragging = true;
                _drag.draggingPanelId = f.panelId;
              });
            },
            onDragUpdate: (globalMove) {
              if (_dragFloatIndex != null) {
                setState(() {
                  final idx = _dragFloatIndex!;
                  final desired = globalMove - _dragFloatGrabOffset;
                  _floats[idx].pos = _clampFloatPos(desired, _floats[idx].size);
                });
              }
              _updateHover(globalMove); // lights zones/guides
            },
            onDragEnd: () {
              if (_drag.targetKey != null &&
                  _drag.hoverZone != DropZone.none &&
                  _drag.draggingPanelId != null) {
                final target = _containerByKey[_drag.targetKey]!;
                setState(() {
                  _dockInto(target, _drag.hoverZone, _drag.draggingPanelId!);
                  _floats.removeAt(_dragFloatIndex!); // consumed by docking
                });
              }
              setState(() {
                _dragFloatIndex = null;
                _dragFloatGrabOffset = Offset.zero;
              });
              _resetDrag();
            },
            onClose: () {
              setState(() => _floats.removeAt(i));
            },
            onResize: (sz) {
              setState(() {
                _floats[i].size = sz;
                // also clamp position because size change might push it out
                _floats[i].pos =
                    _clampFloatPos(_floats[i].pos, _floats[i].size);
              });
            },
          );
        }),

        // existing drag overlay (target highlight)
        AnimatedBuilder(
          animation: Listenable.merge([]),
          builder: (_, __) {
            final rect = _currentTargetRect();
            return DragOverlay(drag: _drag, targetRect: rect);
          },
        ),
      ],
    );

    return Column(
      children: [
        Expanded(
            child: Container(color: widget.style.background, child: content)),
      ],
    );
  }

  Widget _buildPanelContent(String panelId) {
    final panel = widget.layout.registry.getById(panelId);
    return Builder(builder: (ctx) => panel.builder(ctx));
  }

  AutoSide _toAuto(DockSide s) {
    switch (s) {
      case DockSide.left:
        return AutoSide.left;
      case DockSide.right:
        return AutoSide.right;
      case DockSide.bottom:
        return AutoSide.bottom;
      case DockSide.center:
        return AutoSide.bottom; // sensible fallback for center
    }
  }

  Widget _buildNode(DockNode node) {
    if (node is SplitNode) {
      return SplitView(
        node: node,
        aBuilder: _buildNode(node.a),
        bBuilder: _buildNode(node.b),
        style: widget.style,
      );
    } else if (node is ContainerNode) {
      final key = GlobalKey();
      _containerByKey[key] = node;
      return _ContainerFrame(
        key: key,
        style: widget.style,
        child: TabsContainer(
          node: node,
          registry: widget.layout.registry,
          style: widget.style,
          onClose: (i) {
            if (!mounted) return;
            setState(() {
              node.panelIds.removeAt(i);
              _simplifyTree();
            });
          },
          onAutoHide: (panelId) {
            if (!mounted) return;
            setState(() {
              _removePanelEverywhere(widget.layout.root, panelId);
              final DockSide declared =
                  widget.layout.registry.getById(panelId).position;
              final AutoSide strip = (declared == DockSide.center)
                  ? AutoSide.left
                  : _toAuto(declared);
              (_autoHidden[strip] ??= <String>[]).add(panelId);
              _simplifyTree();
            });
          },
          onFloatRequest: (panelId, startGlobal) {
            if (!mounted) return;
            setState(() {
              _removePanelEverywhere(widget.layout.root, panelId);

              const w = 420.0, h = 300.0;
              final ob = _overlayBox();
              final center =
                  ob?.size.center(Offset.zero) ?? const Offset(640, 360);
              final desired = (startGlobal ?? center) - const Offset(w / 2, 36);

              final clamped = _clampFloatPos(desired, const Size(w, h));
              _floats.add(_FloatWin(
                panelId: panelId,
                pos: clamped,
                size: const Size(w, h),
              ));
              _simplifyTree();
            });
          },
          onDragStart: (panelId, start) {
            if (!mounted) return;
            setState(() {
              _drag.isDragging = true;
              _drag.draggingPanelId = panelId;
            });
          },
          onDragUpdate: (global) {
            _updateHover(global);
          },
          onDragEnd: () {
            _completeDrop();
            _resetDrag();
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  ContainerNode? _findFirstContainerBySide(DockNode node, DockSide side) {
    ContainerNode? hit;
    void walk(DockNode n) {
      if (hit != null) return;
      if (n is ContainerNode) {
        if (n.side == side) {
          hit = n;
          return;
        }
      } else if (n is SplitNode) {
        walk(n.a);
        walk(n.b);
      }
    }

    walk(node);
    return hit;
  }

  void floatPanel(String panelId, {Offset? originGlobal}) {
    if (!mounted) return;
    setState(() {
      _removePanelEverywhere(widget.layout.root, panelId);

      const w = 420.0, h = 300.0;
      final ob = _overlayBox();
      final screenCenter =
          ob?.size.center(Offset.zero) ?? const Offset(640, 360);
      final anchor = originGlobal ?? screenCenter;

      // put title bar under finger/cursor (≈36px top chrome)
      final desired = anchor - const Offset(w / 2, 36);
      final clamped = _clampFloatPos(desired, const Size(w, h));

      _floats.add(_FloatWin(
        panelId: panelId,
        pos: clamped,
        size: const Size(w, h),
      ));

      _simplifyTree(); // ✅ remove empty containers left behind
    });
  }

  /// Dock a panel to an application edge (same as your drag-to-edge).
  void dockPanelToEdge(String panelId, DockSide side) {
    if (!mounted) return;
    setState(() {
      _dockToEdge(panelId, side); // already removes from everywhere
      _simplifyTree(); // ✅ collapse gaps after split
    });
  }

  /// Dock a panel into a specific container+zone (programmatic drag-end).
  /// If you don't have a key, prefer `dockPanelToEdge`.
  void dockPanelInto(String panelId, GlobalKey targetKey, DropZone zone) {
    final target = _containerByKey[targetKey];
    if (target == null) return;
    if (!mounted) return;
    setState(() {
      _dockInto(target, zone, panelId);
      _simplifyTree(); // ✅ collapse any emptied branch
    });
  }

  void _resetDrag() {
    if (!mounted) return;
    setState(() {
      _drag.isDragging = false;
      _drag.draggingPanelId = null;
      _drag.hoverRect = null;
      _drag.hoverZone = DropZone.none;
      _drag.targetKey = null;
      _drag.lastGlobalPos = null;
      _drag.overTabBar = false;
    });
  }

  void _updateHover(Offset global) {
    Rect? bestRect;
    GlobalKey? bestKey;
    DropZone zone = DropZone.none;

    for (final entry in _containerByKey.entries) {
      final key = entry.key;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final pos = box.localToGlobal(Offset.zero);
      final rect =
          Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
      if (rect.contains(global)) {
        bestRect = rect;
        bestKey = key;
        zone = _classifyZone(rect, global);
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _drag.hoverRect = bestRect;
      _drag.hoverZone = zone;
      _drag.targetKey = bestKey;
    });
  }

  void _completeDrop() {
    if (!_drag.isDragging) return;
    final id = _drag.draggingPanelId;
    final key = _drag.targetKey;
    final zone = _drag.hoverZone;
    if (id != null && key != null && zone != DropZone.none) {
      final target = _containerByKey[key]!;
      if (!mounted) return;
      setState(() {
        _dockInto(target, zone, id);
        _simplifyTree();
      });
    }
  }

  DockSide _declaredSide(String panelId) {
    return widget.layout.registry.getById(panelId).position;
  }

  void _dockInto(ContainerNode target, DropZone zone, String panelId) {
    _removePanelEverywhere(widget.layout.root, panelId);
    switch (zone) {
      case DropZone.center:
      case DropZone.tabbar:
        target.panelIds.add(panelId);
        target.activeIndex = target.panelIds.length - 1;
        break;
      case DropZone.left:
      case DropZone.right:
      case DropZone.top:
      case DropZone.bottom:
        _splitAround(target, zone, panelId);
        break;
      case DropZone.none:
        break;
    }
  }

  void _removePanelEverywhere(DockNode node, String panelId) {
    if (node is ContainerNode) {
      node.panelIds.removeWhere((id) => id == panelId);
      if (node.activeIndex >= node.panelIds.length) {
        node.activeIndex = node.panelIds.isEmpty ? 0 : node.panelIds.length - 1;
      }
    } else if (node is SplitNode) {
      _removePanelEverywhere(node.a, panelId);
      _removePanelEverywhere(node.b, panelId);
    }
  }

  DockNode _collapseEmpty(DockNode node) {
    if (node is ContainerNode) {
      if (node.panelIds.isEmpty) {
        return ContainerNode(panelIds: [], side: node.side);
      }
    } else if (node is SplitNode) {
      node.a = _collapseEmpty(node.a);
      node.b = _collapseEmpty(node.b);
      if (node.a is ContainerNode &&
          (node.a as ContainerNode).panelIds.isEmpty) {
        return node.b;
      }
      if (node.b is ContainerNode &&
          (node.b as ContainerNode).panelIds.isEmpty) {
        return node.a;
      }
    }
    return node;
  }

  void _simplifyTree() {
    widget.layout.root = _collapseEmpty(widget.layout.root);
  }

  DockNode? _findParent(DockNode root, DockNode child) {
    DockNode? parent;
    void walk(DockNode n) {
      if (n is SplitNode) {
        if (identical(n.a, child) || identical(n.b, child)) {
          parent = n;
          return;
        }
        walk(n.a);
        if (parent != null) return;
        walk(n.b);
      }
    }

    walk(root);
    return parent;
  }

  void _splitAround(ContainerNode target, DropZone zone, String panelId) {
    final newContainer = ContainerNode(
        panelIds: [panelId], activeIndex: 0, side: DockSide.center);
    if (identical(widget.layout.root, target)) {
      widget.layout.root = _splitForZone(zone, target, newContainer);
    } else {
      final parent = _findParent(widget.layout.root, target);
      if (parent is SplitNode) {
        final newSplit = _splitForZone(zone, target, newContainer);
        if (identical(parent.a, target)) {
          parent.a = newSplit;
        } else if (identical(parent.b, target)) {
          parent.b = newSplit;
        }
      } else {
        widget.layout.root = _splitForZone(zone, target, newContainer);
      }
    }
  }

  DockNode _splitForZone(
      DropZone zone, ContainerNode target, ContainerNode newContainer) {
    switch (zone) {
      case DropZone.left:
        return SplitNode(
            axis: SplitAxis.horizontal, ratio: 0.5, a: newContainer, b: target);
      case DropZone.right:
        return SplitNode(
            axis: SplitAxis.horizontal, ratio: 0.5, a: target, b: newContainer);
      case DropZone.top:
        return SplitNode(
            axis: SplitAxis.vertical, ratio: 0.5, a: newContainer, b: target);
      case DropZone.bottom:
        return SplitNode(
            axis: SplitAxis.vertical, ratio: 0.5, a: target, b: newContainer);
      case DropZone.center:
      case DropZone.tabbar:
      case DropZone.none:
        return target;
    }
  }

  DropZone _classifyZone(Rect rect, Offset p) {
    final tabbar = Rect.fromLTWH(rect.left, rect.top, rect.width, 32);
    final left =
        Rect.fromLTWH(rect.left, rect.top, rect.width * 0.25, rect.height);
    final right = Rect.fromLTWH(rect.left + rect.width * 0.75, rect.top,
        rect.width * 0.25, rect.height);
    final top =
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.25);
    final bottom = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.75,
        rect.width, rect.height * 0.25);
    final center = Rect.fromLTWH(rect.left + rect.width * 0.25,
        rect.top + rect.height * 0.25, rect.width * 0.5, rect.height * 0.5);

    if (tabbar.contains(p)) return DropZone.tabbar;
    if (left.contains(p)) return DropZone.left;
    if (right.contains(p)) return DropZone.right;
    if (top.contains(p)) return DropZone.top;
    if (bottom.contains(p)) return DropZone.bottom;
    if (center.contains(p)) return DropZone.center;
    return DropZone.none;
  }

  RenderBox? _overlayBox() =>
      Overlay.of(context)?.context.findRenderObject() as RenderBox?;

  Offset _clampFloatPos(Offset pos, Size winSize) {
    final ob = _overlayBox();
    if (ob == null || !ob.hasSize) return pos;

    final view = ob.size; // overlay is in global space (0,0) origin
    const pad = 8.0; // keep a small margin from screen edges
    const visX = 64.0; // minimal visible width
    const visY = 32.0; // minimal visible height (e.g., titlebar)

    final minX = -winSize.width + visX + pad;
    final maxX = view.width - visX - pad;

    final minY = pad;
    final maxY = view.height - visY - pad;

    double x = pos.dx;
    double y = pos.dy;

    if (x < minX) x = minX;
    if (x > maxX) x = maxX;
    if (y < minY) y = minY;
    if (y > maxY) y = maxY;

    return Offset(x, y);
  }

  Rect? _currentTargetRect() {
    final key = _drag.targetKey;
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);
  }

  void _dockToEdge(String panelId, DockSide side) {
    _removePanelEverywhere(widget.layout.root, panelId);
    final DockNode fresh = ContainerNode(panelIds: [panelId], side: side);
    final DockNode r = widget.layout.root;

    switch (side) {
      case DockSide.left:
        widget.layout.root =
            SplitNode(axis: SplitAxis.horizontal, ratio: .22, a: fresh, b: r);
        break;
      case DockSide.right:
        widget.layout.root =
            SplitNode(axis: SplitAxis.horizontal, ratio: .78, a: r, b: fresh);
        break;
      case DockSide.bottom:
        widget.layout.root =
            SplitNode(axis: SplitAxis.vertical, ratio: .75, a: r, b: fresh);
        break;
      case DockSide.center:
        // Not a real edge; ignore or treat as split if you like.
        widget.layout.root =
            SplitNode(axis: SplitAxis.vertical, ratio: .50, a: r, b: fresh);
        break;
    }
  }
}

class _ContainerFrame extends StatelessWidget {
  final Widget child;
  final DockStyle style;
  const _ContainerFrame(
      {super.key, required this.child, this.style = const DockStyle()});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: style.surface,
          border: Border.all(color: style.border, width: 1)),
      child: child,
    );
  }
}

/// ---------- Floating window widget (inline; no new file) ----------
typedef _FloatDragStart = void Function(Offset globalDown, Offset grabOffset);
typedef _FloatDragUpdate = void Function(Offset globalMove);
typedef _FloatDragEnd = void Function();
typedef _FloatResize = void Function(Size newSize);

class _FloatingPanel extends StatelessWidget {
  final String panelId;
  final String title;
  final Widget content;
  final Offset pos; // global top-left
  final Size size;
  final DockStyle style;
  final _FloatDragStart onDragStart;
  final _FloatDragUpdate onDragUpdate;
  final _FloatDragEnd onDragEnd;
  final VoidCallback onClose;
  final _FloatResize onResize;

  const _FloatingPanel({
    super.key,
    required this.panelId,
    required this.title,
    required this.content,
    required this.pos,
    required this.size,
    required this.style,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onClose,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    final overlayBox =
        Overlay.of(context)!.context.findRenderObject() as RenderBox;
    final local = overlayBox.globalToLocal(pos);
    const titleBarH = 28.0;

    return Positioned(
      left: local.dx,
      top: local.dy,
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.surface,
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF000000).withOpacity(.35),
                blurRadius: 16,
                spreadRadius: 2)
          ],
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            children: [
              FloatTitleBar(
                title: title,
                style: style,
                height: titleBarH,

                // 👉 compute grab offset in *panel/global* space
                onDragStart: (globalDown, _localDown) {
                  final overlayBox = Overlay.of(context)!
                      .context
                      .findRenderObject() as RenderBox;
                  final panelTopLeftGlobal = overlayBox.localToGlobal(
                    overlayBox
                        .globalToLocal(pos), // 'pos' is already global top-left
                  );
                  final grabFromPanel =
                      globalDown - panelTopLeftGlobal; // same space!
                  onDragStart(globalDown,
                      grabFromPanel); // <-- this is what DockAds expects
                },

                // always forward absolute global pointer position
                onDragUpdate: (globalPos) => onDragUpdate(globalPos),
                onDragEnd: onDragEnd,
                onClose: onClose,
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: style.surface2),
                  child: content,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Listener(
                  onPointerMove: (e) {
                    final w = (size.width + e.delta.dx).clamp(240.0, 1200.0);
                    final h = (size.height + e.delta.dy).clamp(160.0, 900.0);
                    onResize(Size(w.toDouble(), h.toDouble()));
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: style.surface,
                      border: Border(
                          top: BorderSide(color: style.border),
                          left: BorderSide(color: style.border)),
                    ),
                    child:
                        const Icon(WindowsIcons.resize_mouse_medium, size: 10),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- Dock guides overlay (cross + edges) ----------
class _DockGuidesOverlay extends StatelessWidget {
  final Rect? targetRect;
  final DropZone hoverZone;
  final DockStyle style;

  const _DockGuidesOverlay({
    required this.targetRect,
    required this.hoverZone,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (targetRect == null) return const SizedBox.shrink();
    final r = targetRect!;
    const double s = 28; // guide button size
    const double pad = 8;

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
