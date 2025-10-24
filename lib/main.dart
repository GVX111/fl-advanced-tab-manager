import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_layout.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_spec.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_insert_mode.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/persistence.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:fluent_ui/fluent_ui.dart';
import 'dockx_ads/widgets/dock_view.dart';
import 'dockx_ads/core/theme.dart';

void main() {
  runApp(const DockXAdsDemo());
}

class DockXAdsDemo extends StatelessWidget {
  const DockXAdsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: IDETheme.background,
        cardColor: IDETheme.surface,
        accentColor: Colors.blue,
        inactiveColor: IDETheme.border,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late final DockPanelRegistry reg;
  late DockLayout layout;

  int _editorCount = 1;
  int _explorerCount = 1;
  int _inspectorCount = 1;
  int _consoleCount = 1;

  @override
  void initState() {
    super.initState();
    reg = DockPanelRegistry();
    // Start EMPTY to avoid bad-state when nothing is registered yet.
    layout = DockLayout.empty(reg);
  }

  // ----------------- Export / Import helpers -----------------

  Future<void> _showExportDialog() async {
    final json = layout.exportPerspectiveJson();
    final controller = TextEditingController(text: json);
    await showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('Export Perspective (read-only)'),
        content: SizedBox(
          width: 560,
          child: TextBox(
            controller: controller,
            readOnly: true,
            maxLines: 16,
            minLines: 8,
          ),
        ),
        actions: [
          Button(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Copy JSON'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: controller.text));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('Import Perspective (paste JSON)'),
        content: SizedBox(
          width: 560,
          child: TextBox(
            controller: controller,
            placeholder: 'Paste exported JSON here…',
            maxLines: 16,
            minLines: 8,
          ),
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            child: const Text('Import'),
            onPressed: () {
              Navigator.pop(context);

              final imported = reg.importJson(
                controller.text,
                specFactory: (id) {
                  if (id.startsWith('console-')) {
                    return DockPanelSpec(
                      id: id,
                      title: 'Console',
                      position: DockSide.bottom,
                      builder: (_) => const _Console(),
                    );
                  }
                  // Unknown? return null → will use policy below.
                  return null;
                },
                missingPanelPolicy: MissingPanelPolicy.registerPlaceholder,
              );
              setState(() {
                layout = imported;
              });
            },
          ),
        ],
      ),
    );
  }

  // ----------------- Add buttons -----------------

  void _addExplorer() {
    final id = 'explorer-${_explorerCount++}';
    if (!reg.has(id)) {
      reg.register(DockPanelSpec(
        id: id,
        title: 'Explorer',
        builder: (ctx) => const _Explorer(),
        position: DockSide.left,
      ));
    }
    layout.addPanel(id, zone: DropZone.left, activate: true);

    setState(() {});
  }

  void _addExplorerOnLeft() {
    reg.register(DockPanelSpec(
      id: 'explorer-22',
      title: 'Explorer',
      builder: (ctx) => const _Explorer(),
      position: DockSide.left,
    ));
    layout.addPanel('explorer-22', activate: true, side: DockSide.left);

    reg.register(DockPanelSpec(
      id: "11",
      groupId: "0",
      title: 'Explorer 222',
      builder: (ctx) => const _Explorer(),
      position: DockSide.left,
    ));
    layout.addPanel('11', activate: true, side: DockSide.left);

    reg.register(DockPanelSpec(
      id: "112",
      groupId: "0",
      title: 'Explorer 220',
      builder: (ctx) => const _Explorer(),
      position: DockSide.left,
    ));
    layout.addPanel('112', activate: true, side: DockSide.left);

    setState(() {});
  }

  void _addEditor() {
    final id = 'editor-${_editorCount++}';
    final fileName = 'file$_editorCount.dart';
    if (!reg.has(id)) {
      reg.register(DockPanelSpec(
        id: id,
        title: 'Editor',
        builder: (ctx) => _Editor(filename: fileName),
        position: DockSide.center,
      ));
    }
    layout.addPanel(id, side: DockSide.center, activate: true);
    setState(() {});
  }

  void _addInspector() {
    final id = 'inspector-${_inspectorCount++}';
    if (!reg.has(id)) {
      reg.register(DockPanelSpec(
        id: id,
        title: 'Inspector',
        builder: (ctx) => const _Inspector(),
        position: DockSide.right,
      ));
    }
    layout.addPanel(id, side: DockSide.right, activate: true);
    setState(() {});
  }

  void _addConsole() {
    final id = 'console-${_consoleCount++}';
    if (!reg.has(id)) {
      reg.register(DockPanelSpec(
        id: id,
        title: 'Console',
        builder: (ctx) => const _Console(),
        position: DockSide.bottom,
      ));
    }
    layout.addPanel(id, side: DockSide.bottom, activate: true);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        actions: SizedBox(
          height: 40, // keep command bar constrained
          child: CommandBar(
            overflowBehavior: CommandBarOverflowBehavior.scrolling,
            primaryItems: [
              CommandBarButton(
                icon: const Icon(FluentIcons.open_enrollment),
                label: const Text('Explorer (Left)'),
                onPressed: _addExplorerOnLeft,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.open_enrollment),
                label: const Text('Explorer Tab(Left)'),
                onPressed: _addExplorer,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.edit),
                label: const Text('Editor (Center)'),
                onPressed: _addEditor,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.waffle),
                label: const Text('Inspector (Right)'),
                onPressed: _addInspector,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.s_i_p_move),
                label: const Text('Console (Bottom)'),
                onPressed: _addConsole,
              ),

              const CommandBarSeparator(),

              // NEW: Export / Import perspective
              CommandBarButton(
                icon: const Icon(FluentIcons.save),
                label: const Text('Export'),
                onPressed: _showExportDialog,
              ),
              CommandBarButton(
                icon: const Icon(FluentIcons.open_file),
                label: const Text('Import'),
                onPressed: _showImportDialog,
              ),
              CommandBarButton(
                  icon: const Icon(FluentIcons.clear),
                  label: const Text('Clear'),
                  onPressed: () => setState(() {
                        layout.clear();
                      })),
            ],
          ),
        ),
      ),
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: DockAds(layout: layout),
      ),
    );
  }
}

// ---------------- Demo panel contents ----------------

class _Explorer extends StatelessWidget {
  const _Explorer();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header('EXPLORER'),
        const Expanded(
          child: ListTile.selectable(
            title: Text('lib/'),
            subtitle: Text('dockx_ads/ • demo'),
          ),
        ),
      ],
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header('INSPECTOR'),
        const SizedBox(height: 8),
        InfoLabel(
          label: 'Selection',
          child: TextBox(placeholder: 'No selection', readOnly: true),
        ),
      ],
    );
  }
}

class Problems extends StatelessWidget {
  const Problems();
  @override
  Widget build(BuildContext context) {
    return Column(children: const [
      SizedBox(height: 6),
      Text('Problems', style: TextStyle(fontSize: 14)),
      SizedBox(height: 6),
      Divider(),
      ListTile(
        leading: Icon(FluentIcons.status_error_full),
        title: Text('No problems detected.'),
      ),
    ]);
  }
}

class _Console extends StatelessWidget {
  const _Console();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: TextBox(minLines: 5, maxLines: null, placeholder: 'Logs...'),
    );
  }
}

class _Editor extends StatelessWidget {
  final String filename;
  const _Editor({required this.filename});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _fileHeader(filename),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: TextBox(
              maxLines: null,
              minLines: 20,
              placeholder: '// Editor area (stub)',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- Shared small UI ----------------

Widget _header(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IDETheme.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, letterSpacing: 1.2),
      ),
    );

Widget _fileHeader(String name) => Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: IDETheme.border)),
      ),
      child: Text(
        name,
        style: const TextStyle(fontFamily: 'Consolas, monospace'),
      ),
    );
