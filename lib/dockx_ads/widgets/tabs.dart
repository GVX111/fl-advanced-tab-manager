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
            height: 32,
            decoration: BoxDecoration(
              color: widget.style.surface,
              border: Border(
                  bottom: BorderSide(color: widget.style.border, width: 1)),
            ),
            child: GestureDetector(
              // NEW: double-click on the tabbar background toggles maximize
              onDoubleTap: widget.onToggleMaximize,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ids.length,
                      itemBuilder: (ctx, i) {
                        final id = ids[i];
                        final isActive = i == active;
                        final title = widget.registry.getById(id).title;
                        return _TabButton(
                          title: title,
                          isActive: isActive,
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
                  // NEW: small expand/restore button at the far right
                  if (widget.onToggleMaximize != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(
                          widget.isMaximized
                              ? widget.style.minimizeIcone
                              : widget.style.maximizeIcon,
                          size: 12,
                          // IMPORTANT: no color here, let the style control it
                        ),
                        onPressed: widget.onToggleMaximize,
                        style: ButtonStyle(
                          padding:
                              WidgetStateProperty.all(const EdgeInsets.all(4)),
                          backgroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            if (states.isHovered) return widget.style.accent;
                            return widget.style.surface;
                          }),
                          foregroundColor:
                              WidgetStateProperty.resolveWith((states) {
                            if (states.isHovered) return Colors.white;
                            return widget.style.text;
                          }),
                        ),
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
  final bool isActive;
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
    required this.isActive,
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

  ButtonStyle _iconBtnStyle() {
    return ButtonStyle(
      padding: WidgetStateProperty.all(const EdgeInsets.all(4)),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.isHovered) return widget.style.surface2;
        return widget.style.surface;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderTopColor = widget.isActive
        ? widget.style.accent
        : widget.style.accent.withValues(alpha: 0);
    final borderColor = widget.style.border;
    final borderTopWidth = widget.isActive ? 2.0 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: borderTopColor, width: borderTopWidth),
              right: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, style: TextStyle(fontSize: 12)),
              if (widget.onPinPressed != null) ...[
                const SizedBox(width: 18),
                IconButton(
                  icon: Icon(widget.style.iconPin, size: 12),
                  onPressed: widget.onPinPressed,
                  style: _iconBtnStyle(),
                ),
              ],
              if (widget.onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(widget.style.iconClose, size: 10),
                  onPressed: widget.onClose,
                  style: _iconBtnStyle(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
