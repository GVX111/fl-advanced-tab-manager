import 'package:fluent_ui/fluent_ui.dart';
import 'dockx_ads/core/models.dart';
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
  late final DockLayout layout;

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
    layout.addPanel(id, side: DockSide.left, activate: true);
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
        title: const Text('DockX ADS – Demo'),
        // IMPORTANT: Bound the actions height to avoid "RenderBox was not laid out"
        actions: SizedBox(
          height: 40, // 36–48 is fine
          child: CommandBar(
            overflowBehavior: CommandBarOverflowBehavior.scrolling,
            primaryItems: [
              CommandBarButton(
                icon: const Icon(FluentIcons.open_enrollment),
                label: const Text('Explorer (Left)'),
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
            ],
          ),
        ),
      ),
      content: ScaffoldPage(
        padding: EdgeInsets.zero,
        // If DockAds ever sits inside a Column in your app, wrap it in Expanded.
        // Here it's the direct content so it's already fully constrained.
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

class _Problems extends StatelessWidget {
  const _Problems();
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
