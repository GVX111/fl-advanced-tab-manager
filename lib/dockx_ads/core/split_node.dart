import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_layout.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_panel_runtime.dart';

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
        a: DockLayout.nodeFromJson(j['a'], reg),
        b: DockLayout.nodeFromJson(j['b'], reg),
      );
}
