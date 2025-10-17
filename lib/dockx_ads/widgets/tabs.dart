// lib/ui/tabs.dart
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

  const TabsContainer({
    super.key,
    required this.node,
    required this.registry,
    this.style = const DockStyle(),
    this.onClose,
    required this.onAutoHide,
    required this.onFloatRequest,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
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
        child: const Center(
          child: Text('Empty', style: TextStyle(color: IDETheme.text)),
        ),
      );
    }

    final active = widget.node.activeIndex.clamp(0, ids.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab strip
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: widget.style.surface,
            border: Border(bottom: BorderSide(color: widget.style.border)),
          ),
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
                      // NEW: pin from tab chip → auto-hide this tab
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
            ],
          ),
        ),
        // Active content
        Expanded(
          child: Container(
            color: widget.style.background,
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
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  Offset? _downGlobal;
  bool _dragging = false;
  int _tapCount = 0;
  DateTime? _lastTapAt;
  bool _hover = false; // <-- hover state for the chip

  // button styles with hover using theme colors from DockStyle
  ButtonStyle _iconBtnStyle() {
    return ButtonStyle(
      padding: ButtonState.all(const EdgeInsets.all(4)),
      backgroundColor: ButtonState.resolveWith((states) {
        if (states.isHovering) return widget.style.surface2;
        return widget.style.surface;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBg =
        widget.isActive ? widget.style.background : widget.style.surface;
    final bg = _hover ? widget.style.surface2 : baseBg; // hover bg
    final borderBottomColor =
        widget.isActive ? widget.style.background : widget.style.border;
    final borderTopColor = _hover
        ? (widget.style.accent)
        : widget.style.border; // light accent on hover

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (e) {
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
            color: bg,
            border: Border(
              top: BorderSide(color: borderTopColor, width: 2),
              left: BorderSide(color: widget.style.border),
              right: BorderSide(color: widget.style.border),
              bottom: BorderSide(color: borderBottomColor),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: TextStyle(color: widget.style.text, fontSize: 12)),
              if (widget.onPinPressed != null) ...[
                const SizedBox(width: 18),
                IconButton(
                  icon: Icon(widget.style.iconPin,
                      size: 12, color: widget.style.text),
                  onPressed: widget.onPinPressed,
                  style: _iconBtnStyle(), // hover-aware
                ),
              ],
              if (widget.onClose != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(FluentIcons.chrome_close,
                      size: 10, color: widget.style.text),
                  onPressed: widget.onClose,
                  style: _iconBtnStyle(), // hover-aware
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
