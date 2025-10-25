import 'dart:convert';
import 'package:fl_advanced_tab_manager/dockx_ads/core/container_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/split_node.dart';

class DockLayout {
  DockNode root;
  final DockPanelRegistry registry;

  /// Where a panel prefers to live (used for pin/restore).
  final Map<String, DockSide> preferredSide = {};

  DockLayout({required this.root, required this.registry});

  // ---- Auto Hide state (source of truth) ----
  final Map<AutoSide, List<String>> autoHidden = {
    AutoSide.left: <String>[],
    AutoSide.right: <String>[],
    AutoSide.bottom: <String>[],
  };

  // ---- helpers for auto-hide ----

  bool isAutoHidden(String id) =>
      autoHidden.values.any((list) => list.contains(id));

  /// Hide a panel to a strip (default to its preferred / declared side).
  void autoHide(String id, {AutoSide? side}) {
    // remove from containers first
    removePanel(id);
    final DockSide declared = registry.getById(id).position;
    final AutoSide strip = side ??
        (declared == DockSide.center ? AutoSide.left : _toAuto(declared));
    autoHidden[strip] ??= <String>[];
    if (!autoHidden[strip]!.contains(id)) {
      autoHidden[strip]!.add(id);
    }
  }

  /// Remove a panel from all strips (if present).
  void removeFromAutoHidden(String id) {
    for (final s in autoHidden.keys) {
      autoHidden[s]!.remove(id);
    }
  }

  /// Move an auto-hidden id to another strip (optionally to an index).
  void moveAutoHidden(String id, AutoSide to, {int? at}) {
    if (!isAutoHidden(id)) return;
    removeFromAutoHidden(id);
    final list = autoHidden[to] ??= <String>[];
    final i = (at ?? list.length).clamp(0, list.length);
    list.insert(i, id);
  }

  /// Unhide: insert into a container by DockSide (or its preferred side).
  void unhideToSide(String id, {DockSide? side, bool activate = true}) {
    removeFromAutoHidden(id);
    side ??= preferredSide[id] ?? registry.getById(id).position;
    final c = _ensureContainerForSide(side);
    c.panelIds.add(id);
    if (activate) c.activateById(id);
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
        return AutoSide.left; // fallback
    }
  }

  factory DockLayout.empty(DockPanelRegistry reg) {
    return DockLayout(
      root: ContainerNode(panelIds: const [], side: DockSide.center),
      registry: reg,
    );
  }

  // ---------- PERSISTENCE (EXPORT / IMPORT) ----------

  /// Export full perspective, including auto-hidden strips.
  Map<String, dynamic> toJson() => {
        'root': root.toJson(),
        'autoHidden': {
          'left': List<String>.from(autoHidden[AutoSide.left] ?? const []),
          'right': List<String>.from(autoHidden[AutoSide.right] ?? const []),
          'bottom': List<String>.from(autoHidden[AutoSide.bottom] ?? const []),
        },
      };

  String exportPerspectiveJson() => jsonEncode(toJson());

  /// Import a perspective (tree + autoHidden); prunes hidden ids from containers.
  static DockLayout fromJson(Map<String, dynamic> j, DockPanelRegistry reg) {
    final layout = DockLayout(
      root: nodeFromJson(j['root'], reg),
      registry: reg,
    );

    // Load autoHidden (safe defaults)
    final ah = (j['autoHidden'] as Map?) ?? const {};
    layout.autoHidden[AutoSide.left] =
        List<String>.from((ah['left'] ?? const []) as List);
    layout.autoHidden[AutoSide.right] =
        List<String>.from((ah['right'] ?? const []) as List);
    layout.autoHidden[AutoSide.bottom] =
        List<String>.from((ah['bottom'] ?? const []) as List);

    // Remove hidden ids from containers so they truly move to strips
    _pruneAutoHiddenPanels(layout);

    return layout;
  }

  static DockNode nodeFromJson(Map<String, dynamic> j, DockPanelRegistry reg) {
    final k = j['kind'];
    if (k == 'split') return SplitNode.fromJson(j, reg);
    if (k == 'container') return ContainerNode.fromJson(j);
    throw ArgumentError('Unknown node kind: $k');
  }

  static void _pruneAutoHiddenPanels(DockLayout layout) {
    final hiddenIds = <String>{
      ...layout.autoHidden[AutoSide.left]!,
      ...layout.autoHidden[AutoSide.right]!,
      ...layout.autoHidden[AutoSide.bottom]!,
    };
    if (hiddenIds.isEmpty) return;

    void removeEverywhere(DockNode n) {
      if (n is ContainerNode) {
        n.panelIds.removeWhere(hiddenIds.contains);
        if (n.activeIndex >= n.panelIds.length) {
          n.activeIndex = n.panelIds.isEmpty ? 0 : n.panelIds.length - 1;
        }
      } else if (n is SplitNode) {
        removeEverywhere(n.a);
        removeEverywhere(n.b);
      }
    }

    DockNode collapseEmpty(DockNode n) {
      if (n is SplitNode) {
        n.a = collapseEmpty(n.a);
        n.b = collapseEmpty(n.b);
        if (n.a is ContainerNode && (n.a as ContainerNode).panelIds.isEmpty) {
          return n.b;
        }
        if (n.b is ContainerNode && (n.b as ContainerNode).panelIds.isEmpty) {
          return n.a;
        }
      }
      return n;
    }

    removeEverywhere(layout.root);
    layout.root = collapseEmpty(layout.root);
  }

  /// Old helper kept for compatibility. Now safe even if all lists are empty.
  static DockLayout fromPanels({
    required DockPanelRegistry reg,
    List<String> left = const [],
    List<String> center = const [],
    List<String> right = const [],
    List<String> bottom = const [],
    double bottomFraction = 0.35,
  }) {
    final noPanels =
        left.isEmpty && center.isEmpty && right.isEmpty && bottom.isEmpty;
    if (noPanels) {
      return DockLayout.empty(reg);
    }

    ContainerNode buildTabs(List<String> ids, DockSide side) =>
        ContainerNode(panelIds: List<String>.from(ids), side: side);

    DockNode centerNode = buildTabs(center, DockSide.center);

    DockNode lr = centerNode;
    if (left.isNotEmpty) {
      lr = SplitNode(
        axis: SplitAxis.horizontal,
        ratio: .22,
        a: buildTabs(left.reversed.toList(), DockSide.left),
        b: lr,
      );
    }
    if (right.isNotEmpty) {
      lr = SplitNode(
        axis: SplitAxis.horizontal,
        ratio: .78,
        a: lr,
        b: buildTabs(right.reversed.toList(), DockSide.right),
      );
    }

    DockNode root = lr;
    if (bottom.isNotEmpty) {
      root = SplitNode(
        axis: SplitAxis.vertical,
        ratio: 1 - bottomFraction,
        a: lr,
        b: buildTabs(bottom.reversed.toList(), DockSide.bottom),
      );
    }

    final layout = DockLayout(root: root, registry: reg);

    for (final id in left.reversed) {
      layout.preferredSide[id] = DockSide.left;
    }
    for (final id in right.reversed) {
      layout.preferredSide[id] = DockSide.right;
    }
    for (final id in bottom.reversed) {
      layout.preferredSide[id] = DockSide.bottom;
    }
    for (final id in center.reversed) {
      layout.preferredSide[id] = DockSide.center;
    }

    return layout;
  }

  // ---------- RUNTIME HELPERS (add/remove/activate) ----------

  DockSide _sideFromZone(DropZone? z, DockSide fallback) {
    switch (z) {
      case DropZone.left:
        return DockSide.left;
      case DropZone.right:
        return DockSide.right;
      case DropZone.top:
        return DockSide.bottom;
      case DropZone.bottom:
        return DockSide.bottom;
      case DropZone.center:
      case DropZone.tabbar:
      case DropZone.none:
      case null:
        return fallback;
    }
  }

  /// One API for all scenarios.
  void addPanel(
    String id, {
    DropZone? zone,
    DockSide? side,
    bool activate = true,
    double? edgeFraction,
  }) {
    if (!registry.has(id)) {
      throw ArgumentError('Panel "$id" is not registered.');
    }

    // clean up previous locations
    removePanel(id);
    removeFromAutoHidden(id);

    final spec = registry.getById(id);
    final desiredSide = _sideFromZone(zone, side ?? spec.position);
    preferredSide[id] = desiredSide;
    final String? groupId = spec.groupId;

    // ---------- CENTER + groupId ----------
    if (desiredSide == DockSide.center && groupId != null) {
      // if container with same group exists -> tab into it
      final existingGroup = findContainerByGroup(groupId);
      if (existingGroup != null) {
        existingGroup.panelIds.add(id);
        if (activate) existingGroup.activateById(id);
        return;
      }

      // no group container; try to reuse an EMPTY center container
      final targetCenter = _ensureContainerForSide(DockSide.center);
      final bool canReuseCenter =
          targetCenter.panelIds.isEmpty && (targetCenter.groupId == null);

      if (canReuseCenter) {
        // reuse the empty center container and stamp its groupId
        targetCenter.groupId = groupId;
        targetCenter.panelIds.add(id);
        if (activate) targetCenter.activateById(id);
        return;
      }

      // center already has content -> split around it
      final newC = ContainerNode(
        panelIds: [id],
        activeIndex: 0,
        side: DockSide.center,
        groupId: groupId,
      );
      final z = zone ?? DropZone.right;
      _splitAroundExisting(targetCenter, newC, z);
      if (activate) newC.activateById(id);
      return;
    }

    // ---------- CENTER + NO groupId (own container) ----------
    if (desiredSide == DockSide.center && groupId == null) {
      final targetCenter = _ensureContainerForSide(DockSide.center);

      if (targetCenter.panelIds.isEmpty) {
        // reuse the empty center container instead of splitting (prevents blank space)
        targetCenter.groupId = null; // explicit
        targetCenter.panelIds.add(id);
        if (activate) targetCenter.activateById(id);
        return;
      }

      // center already has content -> create a sibling container by splitting
      final newC = ContainerNode(
        panelIds: [id],
        activeIndex: 0,
        side: DockSide.center,
        groupId: null,
      );
      final z = zone ?? DropZone.right;
      _splitAroundExisting(targetCenter, newC, z);
      if (activate) newC.activateById(id);
      return;
    }

    // ---------- EDGES (unchanged) ----------
    final directional = zone == DropZone.left ||
        zone == DropZone.right ||
        zone == DropZone.top ||
        zone == DropZone.bottom;

    if (directional && desiredSide != DockSide.center) {
      _insertAsNewEdgeLeaf(
        id,
        side: desiredSide,
        groupId: groupId,
        activate: activate,
        fraction: edgeFraction,
      );
      return;
    }

    // default: append as tab into that side container
    final c = _ensureContainerForSide(desiredSide);
    c.panelIds.add(id);
    if (activate) c.activateById(id);
  }
// --- pruning/cleanup ---------------------------------------------------------

  DockNode _collapseEmpty(DockNode n) {
    if (n is ContainerNode)
      return n; // keep as-is; empties are okay here, but we prune via parent
    if (n is SplitNode) {
      n.a = _collapseEmpty(n.a);
      n.b = _collapseEmpty(n.b);

      // If either side is an empty ContainerNode, drop it
      bool _isEmptyContainer(DockNode x) =>
          x is ContainerNode && x.panelIds.isEmpty;

      if (_isEmptyContainer(n.a) && !_isEmptyContainer(n.b)) return n.b;
      if (_isEmptyContainer(n.b) && !_isEmptyContainer(n.a)) return n.a;

      // If both sides are splits/containers but one is degenerate, just keep as-is
      return n;
    }
    return n;
  }

  void _simplifyAfterMutation() {
    root = _collapseEmpty(root);
  }

  void _splitAroundExisting(
      ContainerNode target, ContainerNode add, DropZone zone) {
    // If target is empty, just reuse it instead of splitting (prevents gaps)
    if (target.panelIds.isEmpty) {
      target.groupId = add.groupId;
      target.side = DockSide.center;
      target.panelIds.clear();
      target.panelIds.addAll(add.panelIds);
      target.activeIndex = target.panelIds.length - 1;
      _simplifyAfterMutation();
      return;
    }

    DockNode _splitForZone(DropZone z, ContainerNode t, ContainerNode n) {
      switch (z) {
        case DropZone.left:
          return SplitNode(axis: SplitAxis.horizontal, ratio: 0.5, a: n, b: t);
        case DropZone.right:
          return SplitNode(axis: SplitAxis.horizontal, ratio: 0.5, a: t, b: n);
        case DropZone.top:
          return SplitNode(axis: SplitAxis.vertical, ratio: 0.5, a: n, b: t);
        case DropZone.bottom:
          return SplitNode(axis: SplitAxis.vertical, ratio: 0.5, a: t, b: n);
        case DropZone.center:
        case DropZone.tabbar:
        case DropZone.none:
          return t;
      }
    }

    final parent = _findParent(root, target);
    final replacement = _splitForZone(zone, target, add);

    if (identical(root, target)) {
      root = replacement;
    } else if (parent is SplitNode) {
      if (identical(parent.a, target))
        parent.a = replacement;
      else if (identical(parent.b, target)) parent.b = replacement;
    }
    _simplifyAfterMutation(); // <- important
  }

// Create a brand-new leaf at an edge, keep edge width/height constant across multiple inserts.
  void _insertAsNewEdgeLeaf(
    String id, {
    required DockSide side,
    String? groupId,
    required bool activate,
    double? fraction,
  }) {
    final double fDefault = (side == DockSide.bottom) ? 0.32 : 0.22;
    final double f = (fraction ?? fDefault).clamp(0.05, 0.90);

    final leaf = ContainerNode(
      panelIds: [id],
      activeIndex: 0,
      side: side,
      groupId: groupId,
    );
    if (activate) leaf.activateById(id);

    // Wrap the whole root once with a split that places the new leaf on the chosen edge.
    if (side == DockSide.left) {
      root = SplitNode(axis: SplitAxis.horizontal, ratio: f, a: leaf, b: root);
    } else if (side == DockSide.right) {
      root =
          SplitNode(axis: SplitAxis.horizontal, ratio: 1 - f, a: root, b: leaf);
    } else if (side == DockSide.bottom) {
      root =
          SplitNode(axis: SplitAxis.vertical, ratio: 1 - f, a: root, b: leaf);
    } else {
      // center fallback: just add as a tab to center
      final c = _ensureContainerForSide(DockSide.center);
      c.panelIds.add(id);
      if (activate) c.activateById(id);
      return;
    }

    // Normalize all edge leaves so each takes a constant fraction f (doesn't shrink every time).
    _rebalanceEdge(side, f);
  }

// Keep all leaves on the same edge at the same global size fraction.
  void _rebalanceEdge(DockSide side, double f) {
    f = f.clamp(0.05, 0.90);

    if (side == DockSide.left) {
      SplitNode? cur = (root is SplitNode) ? root as SplitNode : null;
      double remaining = 1.0;
      while (cur != null &&
          cur.axis == SplitAxis.horizontal &&
          cur.a is ContainerNode &&
          (cur.a as ContainerNode).side == DockSide.left) {
        final r = (f / remaining).clamp(0.05, 0.95);
        cur.ratio = r;
        remaining *= (1.0 - r);
        cur = (cur.b is SplitNode) ? cur.b as SplitNode : null;
      }
    } else if (side == DockSide.right) {
      SplitNode? cur = (root is SplitNode) ? root as SplitNode : null;
      double remaining = 1.0;
      while (cur != null &&
          cur.axis == SplitAxis.horizontal &&
          cur.b is ContainerNode &&
          (cur.b as ContainerNode).side == DockSide.right) {
        final r = (1.0 - (f / remaining)).clamp(0.05, 0.95);
        cur.ratio = r;
        remaining *= r;
        cur = (cur.a is SplitNode) ? cur.a as SplitNode : null;
      }
    } else if (side == DockSide.bottom) {
      SplitNode? cur = (root is SplitNode) ? root as SplitNode : null;
      double remaining = 1.0;
      while (cur != null &&
          cur.axis == SplitAxis.vertical &&
          cur.b is ContainerNode &&
          (cur.b as ContainerNode).side == DockSide.bottom) {
        final r = (1.0 - (f / remaining)).clamp(0.05, 0.95);
        cur.ratio = r;
        remaining *= r;
        cur = (cur.a is SplitNode) ? cur.a as SplitNode : null;
      }
    }
  }

// Parent lookup (you already had a version)
  DockNode? _findParent(DockNode rootNode, DockNode child) {
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

    walk(rootNode);
    return parent;
  }

  bool activatePanel(String id) {
    bool activated = false;
    _visitContainers((c) {
      final idx = c.panelIds.indexOf(id);
      if (idx >= 0) {
        c.activeIndex = idx;
        activated = true;
      }
    });
    return activated;
  }

  bool clear() {
    registry.clear();
    autoHidden[AutoSide.left]!.clear();
    autoHidden[AutoSide.right]!.clear();
    autoHidden[AutoSide.bottom]!.clear();
    preferredSide.clear();
    root = DockLayout.empty(registry).root;
    return true;
  }

  bool removePanel(String id, {bool removeAll = true}) {
    bool removed = false;
    _visitContainers((c) {
      final idx = c.panelIds.indexOf(id);
      if (idx >= 0) {
        c.panelIds.removeAt(idx);
        c.clampActive();
        removed = true;
        if (!removeAll) return;
      }
    });
    return removed;
  }

  bool get isCompletelyEmpty {
    var empty = true;
    _visitContainers((c) {
      if (c.panelIds.isNotEmpty) empty = false;
    });
    return empty;
  }

  // ---------- internal helpers ----------

  void _visitContainers(void Function(ContainerNode) fn) {
    void visit(DockNode n) {
      if (n is ContainerNode) {
        fn(n);
      } else if (n is SplitNode) {
        visit(n.a);
        visit(n.b);
      }
    }

    visit(root);
  }

  ContainerNode _ensureCenterContainer() {
    final center = _maybeGetSide(DockSide.center);
    if (center != null) return center;

    if (root is ContainerNode) {
      final c = root as ContainerNode;
      c.side = DockSide.center;
      return c;
    }

    final newCenter = ContainerNode(panelIds: const [], side: DockSide.center);
    root =
        SplitNode(axis: SplitAxis.vertical, ratio: 0.7, a: newCenter, b: root);
    return newCenter;
  }

  ContainerNode _ensureContainerForSide(DockSide side) {
    final existing = _maybeGetSide(side);
    if (existing != null) return existing;

    if (side == DockSide.center) return _ensureCenterContainer();

    _ensureCenterContainer(); // make sure structure exists
    if (side == DockSide.left) {
      root = SplitNode(
        axis: SplitAxis.horizontal,
        ratio: .22,
        a: ContainerNode(panelIds: const [], side: DockSide.left),
        b: root,
      );
    } else if (side == DockSide.right) {
      root = SplitNode(
        axis: SplitAxis.horizontal,
        ratio: .78,
        a: root,
        b: ContainerNode(panelIds: const [], side: DockSide.right),
      );
    } else if (side == DockSide.bottom) {
      root = SplitNode(
        axis: SplitAxis.vertical,
        ratio: .65,
        a: root,
        b: ContainerNode(panelIds: const [], side: DockSide.bottom),
      );
    }
    return _maybeGetSide(side) ?? _ensureCenterContainer();
  }

  ContainerNode? _maybeGetSide(DockSide side) {
    ContainerNode? hit;
    _visitContainers((c) {
      if (hit == null && c.side == side) hit = c;
    });
    return hit;
  }
}

extension _Finders on DockLayout {
  ContainerNode? findContainerByGroup(String groupId) {
    ContainerNode? hit;
    _visitContainers((c) {
      if (hit == null && c.groupId == groupId) hit = c;
    });
    return hit;
  }
}
