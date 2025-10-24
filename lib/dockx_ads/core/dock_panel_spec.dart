import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:flutter/widgets.dart';

class DockPanelSpec {
  final String id;
  final String title;
  final Widget Function(BuildContext) builder;
  final DockSide position;
  final String? groupId; // NEW

  const DockPanelSpec({
    required this.id,
    required this.title,
    required this.builder,
    this.position = DockSide.center,
    this.groupId, // NEW
  });
}

class DockPanelRuntime {
  final String id;
  final String title;
  final WidgetBuilder builder;
  final DockSide position;
  final String? groupId; // NEW
  DockPanelRuntime({
    required this.id,
    required this.title,
    required this.builder,
    required this.position,
    this.groupId, // NEW
  });
}
