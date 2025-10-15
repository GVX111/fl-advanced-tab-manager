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
    final specs = <DockPanelSpec>[
      DockPanelSpec(
          id: 'explorer',
          title: 'Explorer',
          builder: (_) => const _Explorer(),
          position: DockSide.left),
      DockPanelSpec(
          id: 'inspector',
          title: 'Inspector',
          builder: (_) => const _Inspector(),
          position: DockSide.right),
      DockPanelSpec(
          id: 'problems',
          title: 'Problems',
          builder: (_) => const _Problems(),
          position: DockSide.bottom),
      DockPanelSpec(
          id: 'console',
          title: 'Output',
          builder: (_) => const _Console(),
          position: DockSide.bottom),
      DockPanelSpec(
          id: 'editor1',
          title: 'main.dart',
          builder: (_) => const _Editor(filename: 'main.dart'),
          position: DockSide.center),
      DockPanelSpec(
          id: 'editor2',
          title: 'home.dart',
          builder: (_) => const _Editor(filename: 'home.dart'),
          position: DockSide.center),
    ];

    final reg = DockPanelRegistry()..addAll(specs);
    final layout = DockLayout.fromPanels(
      reg: reg,
      left: const ['explorer', 'editor1', 'editor2'],
      right: const ['inspector'],
      bottom: const ['problems', 'console'],
    );

    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: IDETheme.background,
        cardColor: IDETheme.surface,
        accentColor: Colors.blue,
        inactiveColor: IDETheme.border,
      ),
      home: NavigationView(
        content: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: DockAds(layout: layout),
        ),
      ),
    );
  }
}

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
                title: Text('lib/'), subtitle: Text('dockx_ads/ • demo'))),
      ],
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header('INSPECTOR'),
      const SizedBox(height: 8),
      InfoLabel(
          label: 'Selection',
          child: TextBox(placeholder: 'No selection', readOnly: true)),
    ]);
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
          title: Text('No problems detected.')),
    ]);
  }
}

class _Console extends StatelessWidget {
  const _Console();
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8),
        child: TextBox(minLines: 5, maxLines: null, placeholder: 'Logs...'));
  }
}

class _Editor extends StatelessWidget {
  final String filename;
  const _Editor({required this.filename});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _fileHeader(filename),
      const Expanded(
          child: Padding(
              padding: EdgeInsets.all(12),
              child: TextBox(
                  maxLines: null,
                  minLines: 20,
                  placeholder: '// Editor area (stub)'))),
    ]);
  }
}

Widget _header(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: IDETheme.border))),
      alignment: Alignment.centerLeft,
      child:
          Text(text, style: const TextStyle(fontSize: 12, letterSpacing: 1.2)),
    );

Widget _fileHeader(String name) => Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: IDETheme.border))),
      child:
          Text(name, style: const TextStyle(fontFamily: 'Consolas, monospace')),
    );
