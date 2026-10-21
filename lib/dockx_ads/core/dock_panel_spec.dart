import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:flutter/widgets.dart';

class DockPanelSpec {
  final String id;
  final String title;
  final Widget Function(BuildContext) builder;
  final DockSide position;
  final String? groupId; // NEW

  /// Space around the content in an auto-hide flyout; null uses
  /// [DockStyle.flyoutContentPadding].
  final EdgeInsets? flyoutPadding;

  const DockPanelSpec({
    required this.id,
    required this.title,
    required this.builder,
    this.position = DockSide.center,
    this.groupId, // NEW
    this.flyoutPadding,
  });
}

class DockPanelRuntime {
  final String id;
  final String title;
  final WidgetBuilder builder;
  final DockSide position;
  final String? groupId; // NEW
  final EdgeInsets? flyoutPadding;
  DockPanelRuntime({
    required this.id,
    required this.title,
    required this.builder,
    required this.position,
    this.groupId, // NEW
    this.flyoutPadding,
  });
}
