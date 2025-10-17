import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_panel_runtime.dart';

abstract class DockNode {
  DockNodeKind get kind;
  Map<String, dynamic> toJson();
}
