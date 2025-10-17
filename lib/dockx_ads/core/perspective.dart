/// A full snapshot of the dock state you can persist & restore.
class DockPerspective {
  final Map<String, dynamic> layout; // DockLayout.toJson()
  final Map<String, List<String>> autoHidden; // side -> panelIds
  final List<Map<String, dynamic>> floats; // {panelId, x, y, w, h}

  DockPerspective({
    required this.layout,
    required this.autoHidden,
    required this.floats,
  });

  Map<String, dynamic> toJson() => {
        'layout': layout,
        'autoHidden': autoHidden,
        'floats': floats,
      };

  static DockPerspective fromJson(Map<String, dynamic> json) {
    return DockPerspective(
      layout: (json['layout'] as Map).cast<String, dynamic>(),
      autoHidden: ((json['autoHidden'] as Map?) ?? const {}).map((k, v) =>
          MapEntry(k.toString(),
              (v as List?)?.map((e) => e.toString()).toList() ?? const [])),
      floats: ((json['floats'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }
}
