import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
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
