import 'package:flutter/widgets.dart';
enum DropZone { left, right, top, bottom, center, tabbar, none }
enum AutoSide { left, right, bottom }
class DragState {
  bool isDragging = false;
  String? draggingPanelId;
  Rect? hoverRect;
  DropZone hoverZone = DropZone.none;
  GlobalKey? targetKey;
  bool overTabBar = false;
  Offset? lastGlobalPos;
}
