import 'package:fl_advanced_tab_manager/dockx_ads/core/container_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';

class TabsContainer extends StatefulWidget {
  final ContainerNode node;
  final DockPanelRegistry registry;
  final DockStyle style;

  final void Function(int index)? onClose;
  final void Function(String panelId) onAutoHide;

  // Float + global drag API (non-null as in your version)
  final void Function(String panelId, Offset start) onFloatRequest;
  final void Function(String panelId, Offset globalStart) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;

  /// The container the user works in: its active tab gets the accent.
  final bool isFocused;

  // NEW: maximize for this container & optional global "hide tab bar"
  final VoidCallback? onToggleMaximize; // per-container expand/restore
  final bool hideTabBar; // global zen/expand-all flag
  final bool isMaximized;

  const TabsContainer({
    super.key,
    required this.node,
    required this.registry,
    required this.style,
    this.onClose,
    required this.onAutoHide,
    required this.onFloatRequest,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    // NEW:
    required this.isMaximized,
    this.isFocused = false,
    this.onToggleMaximize,
    this.hideTabBar = false,
  });

  @override
  State<TabsContainer> createState() => _TabsContainerState();
}

class _TabsContainerState extends State<TabsContainer> {
  @override
  Widget build(BuildContext context) {
    final ids = widget.node.panelIds;
    if (ids.isEmpty) {
      return Container(
        color: widget.style.surface,
        child: Center(
          child: Text('Empty', style: TextStyle(color: widget.style.text)),
        ),
      );
    }

    final active = widget.node.activeIndex.clamp(0, ids.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab strip (hidden if hideTabBar == true)
        if (!widget.hideTabBar)
          Container(
            height: 30,
            // A neutral strip (an accent tab on an accent strip would not
            // stand out); the focused container's strip is underlined.
            decoration: BoxDecoration(
              color: widget.style.tabStripBackground,
              border: Border(
                  bottom: BorderSide(
                      color: widget.isFocused
                          ? widget.style.accent
                          : widget.style.border,
                      width: widget.isFocused ? 2 : 1)),
            ),
            child: GestureDetector(
              // NEW: double-click on the tabbar background toggles maximize
              onDoubleTap: widget.onToggleMaximize,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    // A tab is never wider than the strip: its title shrinks
                    // (and scrolls) so pin and close stay visible.
                    child: LayoutBuilder(
                      builder: (ctx, box) => ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ids.length,
                      itemBuilder: (ctx, i) {
                        final id = ids[i];
                        final isActive = i == active;
                        final title = widget.registry.getById(id).title;
                        return _TabButton(
                          maxWidth: box.maxWidth,
                          title: title,
                          isActive: isActive,
                          isFocused: widget.isFocused,
                          style: widget.style,
                          onTap: () {
                            if (!mounted) return;
                            setState(() => widget.node.activeIndex = i);
                          },
                          onClose: widget.onClose == null
                              ? null
                              : () {
                                  if (!mounted) return;
                                  widget.onClose!(i);
                                },
                          // pin from tab chip → auto-hide this tab
                          onPinPressed: () => widget.onAutoHide(id),

                          // Float & drag
                          onDoubleTap: (pos) => widget.onFloatRequest(id, pos),
                          onDragStart: (p) => widget.onDragStart(id, p),
                          onDragUpdate: widget.onDragUpdate,
                          onDragEnd: widget.onDragEnd,
                        );
                      },
                    ),
                    ),
                  ),
                  // NEW: small expand/restore button at the far right
                  if (widget.onToggleMaximize != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: DockIconButton(
                        icon: widget.isMaximized
                            ? widget.style.minimizeIcone
                            : widget.style.maximizeIcon,
                        size: 12,
                        color: widget.style.text,
                        tooltip: widget.isMaximized ? 'Restore' : 'Maximize',
                        onPressed: widget.onToggleMaximize!,
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Active content
        Expanded(
          child: Container(
            child: Builder(
              builder: (ctx) {
                final id = ids[active];
                final panel = widget.registry.getById(id);
                return panel.builder(ctx);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatefulWidget {
  final String title;

  /// Width of the tab strip: the tab never grows past it.
  final double maxWidth;
  final bool isActive;

  /// The tab's container is the focused one.
  final bool isFocused;
  final DockStyle style;
  final VoidCallback onTap;
  final VoidCallback? onClose;
  final VoidCallback? onPinPressed;

  final void Function(Offset globalPos) onDoubleTap;
  final void Function(Offset globalPos) onDragStart;
  final void Function(Offset globalPos) onDragUpdate;
  final VoidCallback onDragEnd;

  const _TabButton({
    required this.title,
    this.maxWidth = double.infinity,
    required this.isActive,
    this.isFocused = false,
    required this.style,
    required this.onTap,
    required this.onClose,
    this.onPinPressed,
    required this.onDoubleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_TabButton> createState() => _TabWidgetStateProperty();
}

class _TabWidgetStateProperty extends State<_TabButton> {
  Offset? _downGlobal;
  bool _dragging = false;
  int _tapCount = 0;
  DateTime? _lastTapAt;

  bool _hover = false;



  @override
  Widget build(BuildContext context) {
    // Focused container: its active tab in the accent colour. Other
    // containers: their active tab lighter than the strip. Inactive tabs
    // are dimmer (lighter on hover).
    final st = widget.style;
    final focusedActive = widget.isActive && widget.isFocused;
    final Color bg = focusedActive
        ? st.tabFocusedActiveBackground
        : widget.isActive
            ? st.tabActiveBackground
            : (_hover ? st.text.withValues(alpha: 0.06) : const Color(0x00000000));
    final Color fg = focusedActive
        ? st.tabFocusedActiveText
        : widget.isActive
            ? st.text
            : (_hover ? st.text : st.tabInactiveText);
    final borderColor = st.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (e) {
          // NEW: middle-click closes this tab immediately on desktop
          const int kMiddleMouseMask =
              0x04; // Primary=0x01, Secondary=0x02, Middle=0x04
          if (e.buttons & kMiddleMouseMask != 0) {
            widget.onClose?.call();
            // swallow further handling for this press
            _downGlobal = null;
            _dragging = false;
            _tapCount = 0;
            _lastTapAt = null;
            return;
          }

          _downGlobal = e.position;
          final now = DateTime.now();
          if (_lastTapAt != null &&
              now.difference(_lastTapAt!) < const Duration(milliseconds: 300)) {
            _tapCount += 1;
          } else {
            _tapCount = 1;
          }
          _lastTapAt = now;
        },
        onPointerMove: (e) {
          if (_downGlobal == null) return;
          final moved = (e.position - _downGlobal!).distance;
          if (!_dragging && moved > 6) {
            _dragging = true;
            widget.onDragStart(_downGlobal!);
          }
          if (_dragging) {
            widget.onDragUpdate(e.position);
          }
        },
        onPointerUp: (e) {
          if (_dragging) {
            _dragging = false;
            widget.onDragEnd();
          } else {
            if (_tapCount >= 2) {
              widget.onDoubleTap(_downGlobal ?? e.position);
            } else {
              widget.onTap();
            }
          }
          _downGlobal = null;
          _tapCount = 0;
        },
        child: Container(
          // No alignment: with a max width it would stretch every tab to the
          // whole strip (the Row centres vertically on its own).
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only as wide as the title (a scroll view would take the whole
              // strip and push the other tabs out); shortened with … when the
              // strip is narrow, the full title in the tooltip.
              Flexible(
                child: Tooltip(
                  message: widget.title,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: fg,
                      fontWeight:
                          widget.isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              if (widget.onPinPressed != null) ...[
                const SizedBox(width: 10),
                DockIconButton(
                  icon: widget.style.iconPin,
                  size: 12,
                  color: fg,
                  tooltip: 'Auto-hide',
                  onPressed: widget.onPinPressed!,
                ),
              ],
              if (widget.onClose != null) ...[
                const SizedBox(width: 6),
                DockIconButton(
                  icon: widget.style.iconClose,
                  size: 10,
                  color: fg,
                  tooltip: 'Close',
                  onPressed: widget.onClose!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small icon button of the tab strip with a hover and pressed state of
/// its own, visible on any strip colour (a hover tint of [color]).
class DockIconButton extends StatefulWidget {
  const DockIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 12,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final double size;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  State<DockIconButton> createState() => _DockIconButtonState();
}

class _DockIconButtonState extends State<DockIconButton> {
  bool _hover = false, _down = false;

  @override
  Widget build(BuildContext context) {
    final bg = _down
        ? widget.color.withValues(alpha: 0.30)
        : _hover
            ? widget.color.withValues(alpha: 0.18)
            : const Color(0x00000000);
    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _down = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          setState(() => _down = false);
          widget.onPressed();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: widget.size, color: widget.color),
        ),
      ),
    );
    return widget.tooltip == null
        ? button
        : Tooltip(message: widget.tooltip!, child: button);
  }
}
