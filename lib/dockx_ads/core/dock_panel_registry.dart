import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_spec.dart';

class DockPanelRegistry {
  final Map<String, DockPanelRuntime> _panels = {};

  void register(DockPanelSpec s) {
    _panels[s.id] = DockPanelRuntime(
      id: s.id,
      title: s.title,
      builder: s.builder,
      position: s.position,
      groupId: s.groupId,
    );
  }

  void addAll(List<DockPanelSpec> specs) {
    for (final s in specs) {
      register(s);
    }
  }

  bool has(String id) => _panels.containsKey(id);

  void unregister(String id) => _panels.remove(id);
  void clear() => _panels.clear();

  DockPanelRuntime getById(String id) {
    final p = _panels[id];
    if (p == null) {
      throw ArgumentError('Unknown panel id: $id');
    }
    return p;
  }

  Iterable<String> get ids => _panels.keys;
}
