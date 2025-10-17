import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:flutter/widgets.dart';

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
