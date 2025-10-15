import 'package:flutter/widgets.dart';

class DockPanelSpec {
  final String id;
  final String title;
  final Widget Function(BuildContext) builder;

  /// Preferred side (for restore / pin).
  final DockSide position;

  const DockPanelSpec({
    required this.id,
    required this.title,
    required this.builder,
    this.position = DockSide.center,
  });
}

class DockPanelRuntime {
  final String id;
  final String title;
  final WidgetBuilder builder;
  final DockSide position;
  DockPanelRuntime({
    required this.id,
    required this.title,
    required this.builder,
    required this.position,
  });
}

enum DockNodeKind { split, container }

enum SplitAxis { horizontal, vertical }

enum DockSide { left, right, bottom, center }

abstract class DockNode {
  DockNodeKind get kind;
  Map<String, dynamic> toJson();
}

class SplitNode extends DockNode {
  final SplitAxis axis;
  double ratio;
  DockNode a;
  DockNode b;
  SplitNode({
    required this.axis,
    required this.ratio,
    required this.a,
    required this.b,
  });

  @override
  DockNodeKind get kind => DockNodeKind.split;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'split',
        'axis': axis.name,
        'ratio': ratio,
        'a': a.toJson(),
        'b': b.toJson(),
      };

  static SplitNode fromJson(Map<String, dynamic> j, DockPanelRegistry reg) =>
      SplitNode(
        axis: j['axis'] == 'horizontal'
            ? SplitAxis.horizontal
            : SplitAxis.vertical,
        ratio: (j['ratio'] as num).toDouble(),
        a: DockLayout._nodeFromJson(j['a'], reg),
        b: DockLayout._nodeFromJson(j['b'], reg),
      );
}

class ContainerNode extends DockNode {
  final List<String> panelIds;
  int activeIndex;
  DockSide side;

  ContainerNode({
    required List<String> panelIds,
    this.activeIndex = 0,
    this.side = DockSide.center,
  }) : panelIds = List<String>.from(panelIds) {
    _clampActive();
  }

  bool get isEmpty => panelIds.isEmpty;

  /// If empty, keep 0; if out of range, clamp.
  void _clampActive() {
    if (panelIds.isEmpty) {
      activeIndex = 0;
      return;
    }
    if (activeIndex < 0) activeIndex = 0;
    if (activeIndex >= panelIds.length) activeIndex = panelIds.length - 1;
  }

  /// Safe setter for active tab by id; no-ops if not present.
  void activateById(String id) {
    final idx = panelIds.indexOf(id);
    if (idx >= 0) {
      activeIndex = idx;
      _clampActive();
    }
  }

  @override
  DockNodeKind get kind => DockNodeKind.container;

  @override
  Map<String, dynamic> toJson() => {
        'kind': 'container',
        'panelIds': panelIds,
        'activeIndex': activeIndex,
        'side': side.name,
      };

  static ContainerNode fromJson(Map<String, dynamic> j) => ContainerNode(
        panelIds: List<String>.from((j['panelIds'] as List).cast<String>()),
        activeIndex: (j['activeIndex'] as num?)?.toInt() ?? 0,
        side: _dockSideFromStr(j['side'] as String?),
      ).._clampActive();

  static DockSide _dockSideFromStr(String? s) {
    switch (s) {
      case 'left':
        return DockSide.left;
      case 'right':
        return DockSide.right;
      case 'bottom':
        return DockSide.bottom;
      case 'center':
      default:
        return DockSide.center;
    }
  }
}

class DockPanelRegistry {
  final Map<String, DockPanelRuntime> _panels = {};

  void register(DockPanelSpec s) {
    _panels[s.id] = DockPanelRuntime(
      id: s.id,
      title: s.title,
      builder: s.builder,
      position: s.position,
    );
  }

  void addAll(List<DockPanelSpec> specs) {
    for (final s in specs) {
      register(s);
    }
  }

  bool has(String id) => _panels.containsKey(id);

  void unregister(String id) => _panels.remove(id);

  DockPanelRuntime getById(String id) {
    final p = _panels[id];
    if (p == null) {
      throw ArgumentError('Unknown panel id: $id');
    }
    return p;
  }

  Iterable<String> get ids => _panels.keys;
}

class DockLayout {
  DockNode root;
  final DockPanelRegistry registry;

  /// Where a panel prefers to live (used for pin/restore).
  final Map<String, DockSide> preferredSide = {};

  DockLayout({required this.root, required this.registry});

  /// ✅ NEW: create a truly empty layout (safe root).
  factory DockLayout.empty(DockPanelRegistry reg) {
    return DockLayout(
      root: ContainerNode(panelIds: const [], side: DockSide.center),
      registry: reg,
    );
  }

  Map<String, dynamic> toJson() => {'root': root.toJson()};

  static DockLayout fromJson(Map<String, dynamic> j, DockPanelRegistry reg) =>
      DockLayout(root: _nodeFromJson(j['root'], reg), registry: reg);

  static DockNode _nodeFromJson(Map<String, dynamic> j, DockPanelRegistry reg) {
    final k = j['kind'];
    if (k == 'split') return SplitNode.fromJson(j, reg);
    if (k == 'container') return ContainerNode.fromJson(j);
    throw ArgumentError('Unknown node kind: $k');
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
    // If absolutely nothing was provided, return an empty layout.
    final noPanels =
        left.isEmpty && center.isEmpty && right.isEmpty && bottom.isEmpty;
    if (noPanels) {
      return DockLayout.empty(reg);
    }

    ContainerNode buildTabs(List<String> ids, DockSide side) =>
        ContainerNode(panelIds: List<String>.from(ids), side: side);

    // Prefer provided center; if center is empty but others exist, start center empty.
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

    // Record startup sides for “pin restore”.
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

  /// ---------- RUNTIME HELPERS (add/remove/activate) ----------

  /// Add a panel by id. If the layout is empty, it goes to center.
  /// If a container for the requested side exists, it appends there.
  /// Otherwise it will split from center to create the requested side.
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

    // Find an existing container for that side; otherwise ensure structure.
    final container = _ensureContainerForSide(side);
    final insertAt = atIndex == null
        ? container.panelIds.length
        : atIndex.clamp(0, container.panelIds.length);

    container.panelIds.insert(insertAt, id);
    if (activate) container.activateById(id);
  }

  /// Activate a panel if it exists anywhere.
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

  /// Remove a panel by id (optionally everywhere).
  bool removePanel(String id, {bool removeAll = true}) {
    bool removed = false;
    _visitContainers((c) {
      final idx = c.panelIds.indexOf(id);
      if (idx >= 0) {
        c.panelIds.removeAt(idx);
        c._clampActive();
        removed = true;
        if (!removeAll) return;
      }
    });
    return removed;
  }

  /// Returns true if there are no tabs anywhere.
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

  ContainerNode _findFirstContainerWhere(bool Function(ContainerNode) test) {
    ContainerNode? hit;
    _visitContainers((c) {
      if (hit == null && test(c)) hit = c;
    });
    return hit ?? _ensureCenterContainer();
  }

  ContainerNode _ensureCenterContainer() {
    final center = _maybeGetSide(DockSide.center);
    if (center != null) return center;

    // If root is already a container, use it and mark as center.
    if (root is ContainerNode) {
      final c = root as ContainerNode;
      c.side = DockSide.center;
      return c;
    }

    // Otherwise, wrap the whole root in a vertical split and add a center container.
    final newCenter = ContainerNode(panelIds: const [], side: DockSide.center);
    root =
        SplitNode(axis: SplitAxis.vertical, ratio: 0.7, a: newCenter, b: root);
    return newCenter;
  }

  ContainerNode _ensureContainerForSide(DockSide side) {
    // If a container already has that side, use it.
    final existing = _maybeGetSide(side);
    if (existing != null) return existing;

    // If asking for center, just ensure center.
    if (side == DockSide.center) return _ensureCenterContainer();

    // Otherwise, create structure by splitting against center.
    final center = _ensureCenterContainer();
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
    // Now it exists; fetch it.
    return _maybeGetSide(side) ?? center;
  }

  ContainerNode? _maybeGetSide(DockSide side) {
    ContainerNode? hit;
    _visitContainers((c) {
      if (hit == null && c.side == side) hit = c;
    });
    return hit;
  }
}
