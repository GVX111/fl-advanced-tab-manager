import 'package:fl_advanced_tab_manager/dockx_ads/core/container_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_layout.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/theme.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/animate_blur.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/floating_panel.dart';
import 'package:fluent_ui/fluent_ui.dart';

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

  // Container lookups
  final Map<GlobalKey, ContainerNode> _containerByKey = {};

  // Stable key per ContainerNode (so comparisons during drag stay valid)
  final Map<ContainerNode, GlobalKey> _keyByContainer = {};
  GlobalKey _keyFor(ContainerNode node) =>
      _keyByContainer.putIfAbsent(node, () => GlobalKey());

  GlobalKey? _dragSourceKey;

  AutoSide? _flySide;
  String? _flyPanelId;
  final GlobalKey _hostKey = GlobalKey();

  // floating windows
  final List<_FloatWin> _floats = <_FloatWin>[];
  int? _dragFloatIndex;
  Offset _dragFloatGrabOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final hasLeft =
        (widget.layout.autoHidden[AutoSide.left] ?? const []).isNotEmpty;
    final hasRight =
        (widget.layout.autoHidden[AutoSide.right] ?? const []).isNotEmpty;
    final hasBottom =
        (widget.layout.autoHidden[AutoSide.bottom] ?? const []).isNotEmpty;

    final content = Stack(
      key: _hostKey,
      fit: StackFit.expand,
      children: [
        AutoHideStrip(
          hidden: widget.layout.autoHidden,
          titleOf: (id) => widget.layout.registry.getById(id).title,
          onShowFlyout: (side, id) {
            if (!mounted) return;
            setState(() {
              _flySide = side;
              _flyPanelId = id;
            });
          },

          // enable "move auto-hide"
          onBeginDrag: (side, id, globalDown) {
            _drag.isDragging = true;
            _drag.draggingPanelId = id;
            _drag.targetKey = null;
            _drag.hoverRect = null;
            _drag.hoverZone = DropZone.none;
            _drag.lastGlobalPos = globalDown; // remember for float fallback
            setState(() {}); // show guides immediately
          },
          onDragUpdate: _updateHover,
          onDragEnd: () {
            final id = _drag.draggingPanelId;
            if (id != null) {
              if (_drag.hoverZone != DropZone.none) {
                if (_drag.targetKey != null) {
                  final target = _containerByKey[_drag.targetKey!];
                  if (target != null) {
                    setState(() {
                      _removeFromAllStrips(id);
                      _dockInto(target, _drag.hoverZone, id);
                      _simplifyTree();
                    });
                  }
                } else {
                  // app-edge docking
                  final side = _zoneToSide(_drag.hoverZone);
                  if (side != null) {
                    setState(() {
                      _removeFromAllStrips(id);
                      _dockToEdge(id, side);
                      _simplifyTree();
                    });
                  }
                }
              } else if (_drag.lastGlobalPos != null) {
                setState(() {
                  _removeFromAllStrips(id);
                  floatPanel(id, originGlobal: _drag.lastGlobalPos);
                });
              }
            }
            _resetDrag();
          },

          style: widget.style,
        ),

        Padding(
          padding: EdgeInsets.only(
            left: hasLeft ? widget.style.stripThickness : 0,
            right: hasRight ? widget.style.stripThickness : 0,
            bottom: hasBottom ? widget.style.stripThickness : 0,
          ),
          child: _buildNode(widget.layout.root),
        ),

        // Auto-hide flyout (with reliable onPin args: side, id)
        if (_flySide != null && _flyPanelId != null)
          Positioned.fill(
            bottom: hasBottom ? widget.style.stripThickness : 0,
            child: AutoHideFlyout(
              side: _flySide!,
              panelId: _flyPanelId!,
              title: widget.layout.registry.getById(_flyPanelId!).title,
              content: _buildPanelContent(_flyPanelId!),

              // PIN: unhide to its declared side
              onPin: (side, id) {
                final declared = widget.layout.registry.getById(id).position;
                setState(() {
                  widget.layout.removeFromAutoHidden(id);
                });
                setState(() {
                  widget.layout
                      .unhideToSide(id, side: declared, activate: true);
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

              // NEW: remove from auto-hide (close button in header)
              onRemove: (panelId) {
                setState(() {
                  widget.layout.removeFromAutoHidden(panelId);
                  _flySide = null;
                  _flyPanelId = null;
                });
              },

              // IMPORTANT: close flyout as soon as drag really begins
              onDragStart: (globalStart, panelId) {
                setState(() {
                  _drag.isDragging = true;
                  _drag.draggingPanelId = panelId;
                  _drag.targetKey = null; // clear stale target
                  _drag.hoverRect = null;
                  _drag.hoverZone = DropZone.none;
                  // Close flyout immediately so zones under it receive pointer hits
                  _flySide = null;
                  _flyPanelId = null;
                });
                _updateHover(globalStart); // compute initial hover
              },

              onDragUpdate: _updateHover,

              onDragEnd: () {
                if (_drag.hoverZone != DropZone.none &&
                    _drag.draggingPanelId != null) {
                  if (_drag.targetKey != null) {
                    final target = _containerByKey[_drag.targetKey!];
                    if (target != null) {
                      setState(() {
                        widget.layout
                            .removeFromAutoHidden(_drag.draggingPanelId!);
                        _dockInto(
                            target, _drag.hoverZone, _drag.draggingPanelId!);
                        _simplifyTree();
                      });
                    }
                  } else {
                    final side = _zoneToSide(_drag.hoverZone);
                    if (side != null) {
                      setState(() {
                        widget.layout
                            .removeFromAutoHidden(_drag.draggingPanelId!);
                        _dockToEdge(_drag.draggingPanelId!, side);
                        _simplifyTree();
                      });
                    }
                  }
                }
                _resetDrag();
              },

              style: widget.style,
            ),
          ),

        // Dock guides (cross + edges)
        if (_drag.isDragging) ...[
          _DockGuidesOverlay(
            targetRect: _currentTargetRect(),
            hoverZone:
                (_drag.targetKey != null) ? _drag.hoverZone : DropZone.none,
            style: widget.style,
          ),
        ],

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
                final idx = _dragFloatIndex!;
                final desired = globalMove - _dragFloatGrabOffset;
                setState(() {
                  _floats[idx].pos = _clampFloatPos(desired, _floats[idx].size);
                });
              }
              _updateHover(globalMove); // lights zones/guides
            },
            onDragEnd: () {
              if (_drag.hoverZone != DropZone.none &&
                  _drag.draggingPanelId != null) {
                if (_drag.targetKey != null) {
                  final target = _containerByKey[_drag.targetKey!];
                  if (target != null) {
                    setState(() {
                      _dockInto(
                          target, _drag.hoverZone, _drag.draggingPanelId!);
                      if (_dragFloatIndex != null) {
                        _floats.removeAt(_dragFloatIndex!); // consumed
                      }
                    });
                  }
                } else {
                  final side = _zoneToSide(_drag.hoverZone);
                  if (side != null) {
                    setState(() {
                      _dockToEdge(_drag.draggingPanelId!, side);
                      if (_dragFloatIndex != null) {
                        _floats.removeAt(_dragFloatIndex!);
                      }
                    });
                  }
                }
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
                _floats[i].pos =
                    _clampFloatPos(_floats[i].pos, _floats[i].size);
              });
            },
          );
        }),

        // target highlight (DragOverlay tolerates null)
        DragOverlay(drag: _drag, targetRect: _currentTargetRect()),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: Container(color: widget.style.background, child: content),
        ),
      ],
    );
  }

  bool _isKeyActive(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx is! Element || !ctx.mounted) return false;
    final ro = ctx.renderObject;
    return ro is RenderBox && ro.hasSize && ro.attached;
  }

  /// Rect of a child key **in overlay host coords**, null if inactive.
  Rect? _rectForInOverlay(GlobalKey childKey) {
    if (!_isKeyActive(childKey)) return null;

    final overlayCtx = _hostKey.currentContext;
    final overlayBox = overlayCtx?.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.hasSize || !overlayBox.attached) {
      return null;
    }

    final childBox = childKey.currentContext!.findRenderObject() as RenderBox;
    final topLeftGlobal = childBox.localToGlobal(Offset.zero);
    final topLeftLocal = overlayBox.globalToLocal(topLeftGlobal);
    return Rect.fromLTWH(
      topLeftLocal.dx,
      topLeftLocal.dy,
      childBox.size.width,
      childBox.size.height,
    );
  }

  Rect? _dockHostRect() {
    final rb = _hostKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached || !rb.hasSize) return null;

    final hasLeft =
        (widget.layout.autoHidden[AutoSide.left] ?? const []).isNotEmpty;
    final hasRight =
        (widget.layout.autoHidden[AutoSide.right] ?? const []).isNotEmpty;
    final hasBottom =
        (widget.layout.autoHidden[AutoSide.bottom] ?? const []).isNotEmpty;

    final padL = hasLeft ? widget.style.stripThickness : 0.0;
    final padR = hasRight ? widget.style.stripThickness : 0.0;
    final padB = hasBottom ? widget.style.stripThickness : 0.0;

    final size = rb.size;
    return Rect.fromLTWH(
      padL,
      0,
      size.width - padL - padR,
      size.height - padB,
    );
  }

  void _removePanelCompletely(String id) {
    // remove from containers
    _removePanelEverywhere(widget.layout.root, id);

    // remove from auto-hide strips
    for (final s in widget.layout.autoHidden.keys) {
      widget.layout.autoHidden[s]!.remove(id);
    }

    // remove floating copy if present
    _floats.removeWhere((f) => f.panelId == id);

    // close flyout if we’re showing that panel
    if (_flyPanelId == id) {
      _flyPanelId = null;
      _flySide = null;
    }

    // collapse empties, repaint
    setState(() {
      _simplifyTree();
    });
  }

  /// First alive container’s rect (overlay coords), or null.
  Rect? _firstAliveContainerRectInOverlay() {
    for (final k in _containerByKey.keys) {
      final r = _rectForInOverlay(k);
      if (r != null) return r;
    }
    return null;
  }

  /// Overlay host rect (full area inside your dock host), or null.
  Rect? _overlayHostRect() {
    final overlayCtx = _hostKey.currentContext;
    final overlayBox = overlayCtx?.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached || !overlayBox.hasSize) {
      return null;
    }
    return Offset.zero & overlayBox.size;
  }

  RenderBox? _overlayBox() =>
      Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;

  Widget _buildPanelContent(String panelId) {
    final panel = widget.layout.registry.getById(panelId);
    return Builder(builder: (ctx) => panel.builder(ctx));
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
      final key = _keyFor(node); // STABLE KEY
      _containerByKey[key] = node;

      // Blur decision for THIS container
      final bool isTarget = _drag.isDragging && identical(_drag.targetKey, key);
      final bool isSource = _drag.isDragging && identical(_dragSourceKey, key);
      final double sigma = isTarget
          ? widget.style.dragHoverBlurSigma
          : (isSource ? widget.style.dragSourceBlurSigma : 0.0);

      return AnimatedBlur(
        sigma: sigma,
        durationMs: widget.style.dragBlurMs,
        child: _ContainerFrame(
          key: key,
          style: widget.style,
          child: TabsContainer(
            node: node,
            registry: widget.layout.registry,
            style: widget.style,
            onClose: (i) {
              if (!mounted) return;
              final id = node.panelIds[i];
              _removePanelCompletely(id);
            },
            onAutoHide: (panelId) {
              if (!mounted) return;
              setState(() {
                widget.layout
                    .autoHide(panelId); // will pick declared/preferred side
                _simplifyTree();
              });
            },
            onFloatRequest: (panelId, startGlobal) {
              if (!mounted) return;
              setState(() {
                _removePanelEverywhere(widget.layout.root, panelId);

                const w = 420.0, h = 300.0;
                final desired =
                    startGlobal - const Offset(w / 2, 36); // title under cursor
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
                _dragSourceKey = key; // REMEMBER SOURCE
              });
            },
            onDragUpdate: _updateHover,
            onDragEnd: () {
              _completeDrop();
              _resetDrag();
            },
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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

      _simplifyTree(); // remove empty containers left behind
    });
  }

  /// Dock a panel to an application edge (same as your drag-to-edge).
  void dockPanelToEdge(String panelId, DockSide side) {
    if (!mounted) return;
    setState(() {
      _dockToEdge(panelId, side); // already removes from everywhere
      _simplifyTree(); // collapse gaps after split
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
      _simplifyTree(); // collapse any emptied branch
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
      _dragSourceKey = null;
    });
  }

  Offset _globalToHost(Offset global) {
    final rb = _hostKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached || !rb.hasSize) return global;
    return rb.globalToLocal(global);
  }

  // When no container is hit, classify edges against the overlay host
  DropZone _classifyOverlayEdges(Rect rect, Offset p) {
    final w = rect.width, h = rect.height;
    final left = Rect.fromLTWH(rect.left, rect.top, w * 0.25, h);
    final right = Rect.fromLTWH(rect.left + w * 0.75, rect.top, w * 0.25, h);
    // NO TOP band
    final bottom = Rect.fromLTWH(rect.left, rect.top + h * 0.75, w, h * 0.25);

    if (left.contains(p)) return DropZone.left;
    if (right.contains(p)) return DropZone.right;
    if (bottom.contains(p)) return DropZone.bottom;
    return DropZone.none;
  }

  void _updateHover(Offset global) {
    Rect? bestRect;
    GlobalKey? bestKey;
    DropZone zone = DropZone.none;

    final host = _dockHostRect();
    final pHost = _globalToHost(global); // <<< convert once

    // 1) Prefer edges when near bands (host-local comparisons!)
    if (host != null) {
      final nearLeft = (pHost.dx - host.left) <= IDETheme.edgeSnapBand;
      final nearRight = (host.right - pHost.dx) <= IDETheme.edgeSnapBand;
      final nearBottom = (host.bottom - pHost.dy) <= IDETheme.edgeSnapBand;

      if (nearLeft || nearRight || nearBottom) {
        bestRect = host;
        bestKey = null; // EDGES MODE
        zone = _classifyOverlayEdges(host, pHost);
        setState(() {
          _drag.hoverRect = bestRect;
          _drag.hoverZone = zone;
          _drag.targetKey = bestKey;
        });
        return;
      }
    }

    // 2) Container hit-test (global coords as before)
    final dead = <GlobalKey>[];
    for (final entry in _containerByKey.entries) {
      final key = entry.key;
      if (!_isKeyActive(key)) {
        dead.add(key);
        continue;
      }

      final box = key.currentContext!.findRenderObject() as RenderBox;
      final rect = Rect.fromLTWH(
        box.localToGlobal(Offset.zero).dx,
        box.localToGlobal(Offset.zero).dy,
        box.size.width,
        box.size.height,
      );

      if (rect.contains(global)) {
        bestRect = rect;
        bestKey = key;
        zone = _classifyZone(rect, global); // container cross
        break;
      }
    }
    for (final k in dead) {
      final node = _containerByKey.remove(k);
      if (node != null) _keyByContainer.remove(node);
    }

    // 3) Fallback to host (not near edges) just to show something
    if (bestRect == null && host != null) {
      bestRect = host;
      bestKey = null;
      zone = DropZone.none; // no suggestion if not near bands or container
    }

    setState(() {
      _drag.hoverRect = bestRect;
      _drag.hoverZone = zone;
      _drag.targetKey = bestKey;
    });
  }

  void _removeFromAllStrips(String id) {
    for (final side in widget.layout.autoHidden.keys) {
      widget.layout.autoHidden[side]!.remove(id);
    }
  }

  DockSide? _zoneToSide(DropZone z) {
    switch (z) {
      case DropZone.left:
        return DockSide.left;
      case DropZone.right:
        return DockSide.right;
      case DropZone.top:
        // if you don't support DockSide.top in your model, map to bottom (or add it)
        return DockSide.bottom;
      case DropZone.bottom:
        return DockSide.bottom;
      default:
        return null;
    }
  }

  void _completeDrop() {
    if (!_drag.isDragging) return;
    final id = _drag.draggingPanelId;
    final key = _drag.targetKey;
    final zone = _drag.hoverZone;

    if (id == null || zone == DropZone.none) return;

    if (key == null) {
      // No container target → app-edge docking
      final side = _zoneToSide(zone);
      if (side != null) {
        setState(() {
          _dockToEdge(id, side);
          _simplifyTree();
        });
      }
      return;
    }

    final container = _containerByKey[key];
    if (container == null) return;

    setState(() {
      _dockInto(container, zone, id);
      _simplifyTree();
    });
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
      panelIds: [panelId],
      activeIndex: 0,
      side: DockSide.center,
    );
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
    final tabbar = Rect.fromLTWH(
        rect.left, rect.top, rect.width, widget.style.tabbarHeight);
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

  Offset _clampFloatPos(Offset pos, Size winSize) {
    final ob = _overlayBox();
    if (ob == null || !ob.hasSize) return pos;

    final view = ob.size; // overlay is in global space (0,0) origin
    const pad = 8.0; // margin from screen edges
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
    if (_drag.targetKey == null) {
      return _dockHostRect(); // edges mode anchor
    }
    final tk = _drag.targetKey!;
    final r = _rectForInOverlay(tk);
    if (r != null) return r;

    final node = _containerByKey.remove(tk);
    if (node != null) _keyByContainer.remove(node);
    _drag.targetKey = null;
    return _dockHostRect();
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
        // Not a real edge; treat as split for completeness
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
        border: Border.all(color: style.border, width: 1),
      ),
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
    final overlayRb =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (overlayRb == null || !overlayRb.hasSize) return const SizedBox.shrink();
    final local = overlayRb.globalToLocal(pos);
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000), // ~.35
              blurRadius: 16,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          children: [
            FloatTitleBar(
              title: title,
              style: style,
              height: titleBarH,
              // compute grab offset in *panel/global* space
              onDragStart: (globalDown, _localDown) {
                final overlayBox = Overlay.maybeOf(context)
                    ?.context
                    .findRenderObject() as RenderBox?;
                if (overlayBox == null) return;
                final panelTopLeftGlobal = overlayBox.localToGlobal(
                  overlayBox.globalToLocal(pos),
                );
                final grabFromPanel = globalDown - panelTopLeftGlobal;
                onDragStart(globalDown, grabFromPanel);
              },
              onDragUpdate: onDragUpdate, // forward absolute global pos
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
                child: const SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(WindowsIcons.resize_mouse_medium, size: 10),
                ),
              ),
            ),
          ],
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
  final bool edgesOnly;

  const _DockGuidesOverlay({
    required this.targetRect,
    required this.hoverZone,
    required this.style,
    this.edgesOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (targetRect == null) return const SizedBox.shrink();
    final r = targetRect!;

    // Visuals
    const double s = 28.0; // button size
    const double pad = 8.0; // breathing room from edges

    // Reserve space that must not be overlapped
    final double reserveTop = style.tabbarHeight; // tabbar area (containers)
    final double reserveLeft = style.stripThickness; // auto-hide strip
    final double reserveRight = style.stripThickness; // auto-hide strip
    final double reserveBottom = style.stripThickness; // bottom strip

    // Build an inner rect where buttons must live
    final inner = Rect.fromLTRB(
      r.left + reserveLeft + pad + s / 2,
      r.top + reserveTop + pad + s / 2,
      r.right - reserveRight - pad - s / 2,
      r.bottom - reserveBottom - pad - s / 2,
    );

    if (inner.width < s || inner.height < s) {
      // Area too tight → nothing to draw
      return const SizedBox.shrink();
    }

    // Helpers
    Offset clampPoint(Offset p) => Offset(
          p.dx.clamp(inner.left, inner.right),
          p.dy.clamp(inner.top, inner.bottom),
        );

    Widget btn(DropZone z, IconData icon, Offset c) {
      // Hide if outside inner rect (can happen on extreme sizes)
      if (!inner.inflate(0.01).contains(c)) return const SizedBox.shrink();

      final sel = z == hoverZone;
      return Positioned(
        left: c.dx - s / 2,
        top: c.dy - s / 2,
        width: s,
        height: s,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: sel
                ? (style.accent).withValues(alpha: .95)
                : style.surface2.withValues(alpha: .90),
            border: Border.all(color: style.border, width: 1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 10),
            ],
          ),
          child: Icon(icon, size: 14, color: style.text),
        ),
      );
    }

    // Ideal centers
    final cx = (inner.left + inner.right) / 2;
    final cy = (inner.top + inner.bottom) / 2;

    // Edge positions (kept inside inner)
    final leftC = clampPoint(Offset(inner.left, cy));
    final rightC = clampPoint(Offset(inner.right, cy));
    final topC = clampPoint(Offset(cx, inner.top));
    final bottomC = clampPoint(Offset(cx, inner.bottom));
    final centerC = clampPoint(Offset(cx, cy));

    final children = <Widget>[
      // Left / Right
      btn(DropZone.left, WindowsIcons.dock_left, leftC),
      btn(DropZone.right, WindowsIcons.dock_right, rightC),

      // Top / Bottom
      btn(
        DropZone.top,
        // Flip the bottom icon to point up
        WindowsIcons.dock_bottom,
        topC.translate(0, 0),
      ),
      btn(DropZone.bottom, WindowsIcons.dock_bottom, bottomC),
    ];

    if (!edgesOnly) {
      children.add(btn(DropZone.center, WindowsIcons.dock, centerC));
    }

    return IgnorePointer(child: Stack(children: children));
  }
}
