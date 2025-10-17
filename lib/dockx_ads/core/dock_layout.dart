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

  void addPanel(
    String id, {
    DockSide? side,
    bool activate = true,
    int? atIndex,
  }) {
    if (!registry.has(id)) {
      throw ArgumentError('Panel "$id" is not registered.');
    }

    side ??= registry.getById(id).position;
    preferredSide[id] = side;

    final container = _ensureContainerForSide(side);
    final insertAt = atIndex == null
        ? container.panelIds.length
        : atIndex.clamp(0, container.panelIds.length);

    container.panelIds.insert(insertAt, id);
    if (activate) container.activateById(id);
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
