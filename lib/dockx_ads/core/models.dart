import 'package:flutter/widgets.dart';

class DockPanelSpec {
  final String id;
  final String title;
  final Widget Function(BuildContext) builder;

  /// NEW: where this panel *belongs* (used for pin/auto-hide restore)
  final DockSide position;

  const DockPanelSpec({
    required this.id,
    required this.title,
    required this.builder,
    this.position = DockSide.center, // default if unspecified
  });
}

class DockPanelRuntime {
  final String id;
  final String title;
  final WidgetBuilder builder;
  final DockSide position;
  DockPanelRuntime(
      {required this.id,
      required this.title,
      required this.builder,
      required this.position});
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
  SplitNode(
      {required this.axis,
      required this.ratio,
      required this.a,
      required this.b});
  @override
  DockNodeKind get kind => DockNodeKind.split;
  @override
  Map<String, dynamic> toJson() => {
        'kind': 'split',
        'axis': axis.name,
        'ratio': ratio,
        'a': a.toJson(),
        'b': b.toJson()
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
  ContainerNode(
      {required List<String> panelIds,
      this.activeIndex = 0,
      this.side = DockSide.center})
      : panelIds = List<String>.from(panelIds);
  @override
  DockNodeKind get kind => DockNodeKind.container;
  @override
  Map<String, dynamic> toJson() => {
        'kind': 'container',
        'panelIds': panelIds,
        'activeIndex': activeIndex,
        'side': side.name
      };
  static ContainerNode fromJson(Map<String, dynamic> j) => ContainerNode(
        panelIds: List<String>.from((j['panelIds'] as List).cast<String>()),
        activeIndex: (j['activeIndex'] as num?)?.toInt() ?? 0,
        side: _dockSideFromStr(j['side'] as String?),
      );
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
  void addAll(List<DockPanelSpec> specs) {
    for (final s in specs) {
      _panels[s.id] = DockPanelRuntime(
          id: s.id, title: s.title, builder: s.builder, position: s.position);
    }
  }

  DockPanelRuntime getById(String id) {
    final p = _panels[id];
    if (p == null) {
      throw ArgumentError('Unknown panel id: $id');
    }
    return p;
  }
}

class DockLayout {
  DockNode root;
  final DockPanelRegistry registry;

  // NEW: where a panel prefers to return when pinned from auto-hide
  final Map<String, DockSide> preferredSide = {};

  DockLayout({required this.root, required this.registry});

  Map<String, dynamic> toJson() => {'root': root.toJson()};
  static DockLayout fromJson(Map<String, dynamic> j, DockPanelRegistry reg) =>
      DockLayout(root: _nodeFromJson(j['root'], reg), registry: reg);
  static DockNode _nodeFromJson(Map<String, dynamic> j, DockPanelRegistry reg) {
    final k = j['kind'];
    if (k == 'split') return SplitNode.fromJson(j, reg);
    if (k == 'container') return ContainerNode.fromJson(j);
    throw ArgumentError('Unknown node kind: $k');
  }

  static DockLayout fromPanels({
    required DockPanelRegistry reg,
    List<String> left = const [],
    List<String> center = const [],
    List<String> right = const [],
    List<String> bottom = const [],
    double bottomFraction = 0.35,
  }) {
    ContainerNode buildTabs(List<String> ids, DockSide side) =>
        ContainerNode(panelIds: List<String>.from(ids), side: side);
    DockNode centerNode = buildTabs(
        center.isNotEmpty ? center : [reg._panels.keys.first], DockSide.center);

    DockNode lr = centerNode;
    if (left.isNotEmpty) {
      lr = SplitNode(
          axis: SplitAxis.horizontal,
          ratio: .22,
          a: buildTabs(left.reversed.toList(), DockSide.left),
          b: lr);
    }
    if (right.isNotEmpty) {
      lr = SplitNode(
          axis: SplitAxis.horizontal,
          ratio: .78,
          a: lr,
          b: buildTabs(right.reversed.toList(), DockSide.right));
    }
    DockNode root = lr;
    if (bottom.isNotEmpty) {
      root = SplitNode(
          axis: SplitAxis.vertical,
          ratio: 1 - bottomFraction,
          a: lr,
          b: buildTabs(bottom.reversed.toList(), DockSide.bottom));
    }

    final layout = DockLayout(root: root, registry: reg);

// record startup sides for “pin restore”
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
}
