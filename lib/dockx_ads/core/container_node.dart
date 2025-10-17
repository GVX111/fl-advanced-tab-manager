import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_panel_runtime.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';

class ContainerNode extends DockNode {
  final List<String> panelIds;
  int activeIndex;
  DockSide side;

  ContainerNode({
    required List<String> panelIds,
    this.activeIndex = 0,
    this.side = DockSide.center,
  }) : panelIds = List<String>.from(panelIds) {
    clampActive();
  }

  bool get isEmpty => panelIds.isEmpty;

  /// If empty, keep 0; if out of range, clamp.
  void clampActive() {
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
      clampActive();
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
      )..clampActive();

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
