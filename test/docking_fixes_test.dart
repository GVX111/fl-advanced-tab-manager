import 'package:fl_advanced_tab_manager/dockx_ads/core/container_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_layout.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_spec.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/theme.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/auto_hide.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/tabs.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

List<ContainerNode> containers(DockNode n) => switch (n) {
  ContainerNode c => [c],
  SplitNode s => [...containers(s.a), ...containers(s.b)],
  _ => const [],
};

DockPanelRegistry registry(List<String> ids) {
  final r = DockPanelRegistry();
  for (final id in ids) {
    r.register(DockPanelSpec(id: id, title: id, builder: (_) => Text('content $id')));
  }
  return r;
}

Widget app(Widget child) => FluentApp(
  home: Builder(builder: (context) => ScaffoldPage(content: child)),
);

void main() {
  test('removing a panel drops the container it leaves empty', () {
    final reg = registry(['grid', 'placeholder', 'map']);
    final layout = DockLayout(
      registry: reg,
      root: SplitNode(
        axis: SplitAxis.horizontal,
        ratio: 0.3,
        a: ContainerNode(panelIds: ['grid'], side: DockSide.left),
        b: ContainerNode(panelIds: ['placeholder'], side: DockSide.center),
      ),
    );
    // A panel added next to the placeholder, then the placeholder removed
    // (an app's "nothing open yet" hint): no "Empty" container stays.
    layout.addPanel('map', side: DockSide.center);
    layout.removePanel('placeholder');
    final all = containers(layout.root);
    expect(all.where((c) => c.panelIds.isEmpty), isEmpty);
    expect(all.map((c) => c.panelIds), [
      ['grid'],
      ['map'],
    ]);
    // A later centre panel tabs into the remaining centre container.
    reg.register(DockPanelSpec(id: 'map2', title: 'map2', builder: (_) => const SizedBox()));
    layout.addPanel('map2', side: DockSide.center);
    expect(containers(layout.root).length, 3, reason: 'split next to the map, not into an empty area');
    expect(containers(layout.root).where((c) => c.panelIds.isEmpty), isEmpty);
  });

  testWidgets('an auto-hide flyout fits the dock area, not the whole window', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late DockStyle style;
    await tester.pumpWidget(
      app(
        Center(
          child: SizedBox(
            width: 600,
            height: 400,
            child: Builder(
              builder: (context) {
                style = DockStyle.fromTheme(context);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: AutoHideFlyout(
                        side: AutoSide.right,
                        panelId: 'ai',
                        title: 'AI Assistant',
                        content: const Text('chat'),
                        initialExtent: 300,
                        onPin: (side, id) {},
                        onClose: () {},
                        onRemove: (_) {},
                        onDragStart: (a, b) {},
                        onDragUpdate: (_) {},
                        onDragEnd: () {},
                        style: style,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final area = tester.getRect(find.byType(AutoHideFlyout));
    final panel = tester.getRect(find.text('AI Assistant'));
    final content = tester.getRect(find.text('chat'));
    expect(area.size, const Size(600, 400));
    expect(panel.top, greaterThanOrEqualTo(area.top));
    expect(content.bottom, lessThanOrEqualTo(area.bottom), reason: 'the bottom is not cut off');
    expect(panel.right, lessThanOrEqualTo(area.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('in a narrow strip a tab keeps pin and close visible, the title shrinks', (tester) async {
    final reg = registry(['Kennfeld Beginnwinkel ES1 Superklopfen präventiv (very long title)']);
    final node = ContainerNode(panelIds: [reg.ids.first]);
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 160,
            height: 120,
            child: Builder(
              builder: (context) => TabsContainer(
                node: node,
                registry: reg,
                style: DockStyle.fromTheme(context),
                onClose: (_) {},
                onAutoHide: (_) {},
                onFloatRequest: (a, b) {},
                onDragStart: (a, b) {},
                onDragUpdate: (_) {},
                onDragEnd: () {},
                isMaximized: false,
              ),
            ),
          ),
        ),
      ),
    );
    final style = DockStyle.fromTheme(tester.element(find.byType(TabsContainer)));
    final close = tester.getRect(find.byIcon(style.iconClose));
    final pin = tester.getRect(find.byIcon(style.iconPin));
    expect(close.right, lessThanOrEqualTo(160));
    expect(pin.right, lessThanOrEqualTo(160));
    expect(tester.takeException(), isNull);
  });
}
