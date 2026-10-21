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
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/dock_view.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/split_view.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/widgets/tabs.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

  testWidgets('in a narrow strip a tab keeps pin and close visible, the title shrinks with …', (tester) async {
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

  testWidgets('several tabs in one container are all shown side by side', (tester) async {
    final reg = registry(['Angle > Base', 'Coils', 'Trailing spark']);
    final node = ContainerNode(panelIds: reg.ids.toList());
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 700,
            height: 200,
            child: Builder(
              builder: (context) => TabsContainer(
                node: node,
                registry: reg,
                style: DockStyle.fromTheme(context),
                onClose: (i) {},
                onAutoHide: (id) {},
                onFloatRequest: (a, b) {},
                onDragStart: (a, b) {},
                onDragUpdate: (p) {},
                onDragEnd: () {},
                isMaximized: false,
              ),
            ),
          ),
        ),
      ),
    );
    for (final t in ['Angle > Base', 'Coils', 'Trailing spark']) {
      final r = tester.getRect(find.text(t));
      expect(r.left, greaterThanOrEqualTo(0), reason: t);
      expect(r.right, lessThanOrEqualTo(700), reason: '$t is inside the strip');
    }
    // Each tab only as wide as its title (plus pin and close), not the strip.
    expect(tester.getRect(find.text('Coils')).left, lessThan(350));
    expect(tester.takeException(), isNull);
  });

  test('adding or activating a panel focuses it', () {
    final reg = registry(['a', 'b']);
    final layout = DockLayout(registry: reg, root: ContainerNode(panelIds: ['a']));
    layout.addPanel('b', side: DockSide.right);
    expect(layout.focusedPanelId, 'b');
    layout.activatePanel('a');
    expect(layout.focusedPanelId, 'a');
  });

  testWidgets('the active tab is accent-filled only in the focused container', (tester) async {
    final reg = registry(['one', 'two']);
    Future<Color?> activeColor({required bool focused}) async {
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 600,
            height: 200,
            child: Builder(
              builder: (context) => TabsContainer(
                node: ContainerNode(panelIds: ['one', 'two']),
                registry: reg,
                style: DockStyle.fromTheme(context),
                onClose: (i) {},
                onAutoHide: (id) {},
                onFloatRequest: (a, b) {},
                onDragStart: (a, b) {},
                onDragUpdate: (p) {},
                onDragEnd: () {},
                isMaximized: false,
                isFocused: focused,
              ),
            ),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.ancestor(of: find.text('one'), matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    final focused = await activeColor(focused: true);
    final unfocused = await activeColor(focused: false);
    final style = DockStyle.fromTheme(tester.element(find.byType(TabsContainer)));
    expect(focused, style.tabFocusedActiveBackground);
    expect(unfocused, style.tabActiveBackground);
    expect(focused, isNot(unfocused));
  });

  testWidgets('resizing the right panel does not resize the left one', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // left | centre | right, as (left | centre) | right.
    final inner = SplitNode(axis: SplitAxis.horizontal, ratio: 0.3, a: ContainerNode(panelIds: ['l']), b: ContainerNode(panelIds: ['c']));
    final outer = SplitNode(axis: SplitAxis.horizontal, ratio: 0.7, a: inner, b: ContainerNode(panelIds: ['r']));
    late DockStyle style;
    Widget pane(String k) => SizedBox.expand(key: ValueKey(k));
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 1000,
          height: 300,
          child: Builder(builder: (context) {
            style = DockStyle.fromTheme(context);
            return SplitView(
              node: outer,
              style: style,
              aBuilder: SplitView(node: inner, style: style, aBuilder: pane('left'), bBuilder: pane('centre')),
              bBuilder: pane('right'),
            );
          }),
        ),
      ),
    );
    final leftBefore = tester.getSize(find.byKey(const ValueKey('left'))).width;
    final rightBefore = tester.getSize(find.byKey(const ValueKey('right'))).width;
    // Drag the divider between centre and right 120 px to the left.
    final divider = tester.getTopRight(find.byKey(const ValueKey('centre'))) + const Offset(4, 100);
    // A real drag: frames are drawn while the mouse moves.
    final g = await tester.startGesture(divider);
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('left'))).width, closeTo(leftBefore, 1));
    expect(tester.getSize(find.byKey(const ValueKey('right'))).width, greaterThan(rightBefore + 80));
  });

  testWidgets('the maximize button reacts to the mouse', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      app(Center(child: DockIconButton(icon: FluentIcons.add, color: Colors.white, tooltip: 'Maximize', onPressed: () => pressed++))),
    );
    Color? bg() => ((tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration) as BoxDecoration).color;
    expect(bg(), const Color(0x00000000));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(DockIconButton)));
    await tester.pumpAndSettle();
    expect(bg(), isNot(const Color(0x00000000)), reason: 'hover shows a background');
    await tester.tap(find.byType(DockIconButton));
    expect(pressed, 1);
  });

  for (final (side, begin) in [
    (AutoSide.bottom, const Offset(0, 1)),
    (AutoSide.right, const Offset(1, 0)),
    (AutoSide.left, const Offset(-1, 0)),
  ]) {
    testWidgets('a ${side.name} flyout slides out of its strip and back', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        app(
          SizedBox(
            width: 800,
            height: 500,
            child: Builder(
              builder: (context) => Stack(
                children: [
                  Positioned.fill(
                    child: AutoHideFlyout(
                      side: side,
                      panelId: 'p',
                      title: 'Panel',
                      content: const Text('content'),
                      initialExtent: 260,
                      onPin: (s, id) {},
                      onClose: () => closed = true,
                      onRemove: (id) {},
                      onDragStart: (a, b) {},
                      onDragUpdate: (p) {},
                      onDragEnd: () {},
                      style: DockStyle.fromTheme(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      Offset slide() => tester.widget<SlideTransition>(find.byType(SlideTransition)).position.value;
      expect(slide(), begin, reason: 'starts outside, at its strip');
      await tester.pumpAndSettle();
      expect(slide(), Offset.zero);
      // A click outside closes it: it slides back the same way.
      final area = tester.getRect(find.byType(AutoHideFlyout));
      await tester.tapAt(side == AutoSide.left ? area.topRight + const Offset(-20, 20) : area.topLeft + const Offset(20, 20));
      await tester.pump(); // the animation starts on the next frame
      await tester.pump(const Duration(milliseconds: 60));
      final mid = slide();
      expect(mid.dx * begin.dx + mid.dy * begin.dy, greaterThan(0), reason: 'moving towards the strip');
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  }

  testWidgets('strip chips fit the strip and their text is centred and whole', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late DockStyle style;
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 700,
          height: 500,
          child: Builder(builder: (context) {
            style = DockStyle.fromTheme(context);
            return Stack(children: [
              Positioned.fill(
                child: AutoHideStrip(
                  hidden: {
                    AutoSide.left: ['Explorer'],
                    AutoSide.right: ['Parameters — ALL'],
                    AutoSide.bottom: ['Console'],
                  },
                  titleOf: (id) => id,
                  onShowFlyout: (side, id) {},
                  style: style,
                ),
              ),
            ]);
          }),
        ),
      ),
    );
    final area = tester.getRect(find.byType(AutoHideStrip));
    for (final t in ['Explorer', 'Parameters — ALL', 'Console']) {
      final text = tester.getRect(find.text(t));
      final chip = tester.getRect(find.ancestor(of: find.text(t), matching: find.byType(AnimatedContainer)).first);
      final vertical = t != 'Console';
      // Inside the chip, nothing cut off.
      expect(chip.inflate(0.5).contains(text.topLeft) && chip.inflate(0.5).contains(text.bottomRight), isTrue, reason: '$t inside its chip');
      // Centred across the strip's thickness.
      final off = vertical ? (text.center.dx - chip.center.dx).abs() : (text.center.dy - chip.center.dy).abs();
      expect(off, lessThan(0.25), reason: '$t centred');
      // As thick as the strip allows (4 px round it), whatever the font:
      // the text (line height 1.0) is centred in it, never pushed out.
      final thick = vertical ? chip.width : chip.height;
      expect(thick, closeTo(style.stripThickness - 8, 0.01), reason: '$t chip fits the strip');
      expect(area.inflate(0.5).contains(chip.topLeft) && area.inflate(0.5).contains(chip.bottomRight), isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flyout resizes from its edge without covering its content', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 900,
          height: 500,
          child: Builder(
            builder: (context) => Stack(children: [
              Positioned.fill(
                child: AutoHideFlyout(
                  side: AutoSide.right,
                  panelId: 'p',
                  title: 'Inspector',
                  content: const Align(alignment: Alignment.topLeft, child: Text('Selection')),
                  initialExtent: 300,
                  onPin: (s, id) {},
                  onClose: () {},
                  onRemove: (id) {},
                  onDragStart: (a, b) {},
                  onDragUpdate: (p) {},
                  onDragEnd: () {},
                  style: DockStyle.fromTheme(context),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(SlideTransition));
    expect(panel.width, closeTo(300, 0.5));
    // Idle, the grip draws nothing over the flyout's border.
    final grip = find.descendant(of: find.byType(AutoHideFlyout), matching: find.byType(AnimatedContainer));
    for (final e in grip.evaluate()) {
      final c = tester.widget<Container>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Container)).first);
      expect((c.color ?? const Color(0x00000000)).a, 0, reason: 'the border stays visible');
    }
    // Hover the edge: only a thin line lights up, the text stays visible.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: panel.centerLeft + const Offset(3, 0));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    final lines = find.descendant(of: find.byType(AutoHideFlyout), matching: find.byType(AnimatedContainer));
    final edges = [
      for (final e in lines.evaluate())
        if (tester.getSize(find.byWidget(e.widget)).height > 200) tester.getSize(find.byWidget(e.widget)).width,
    ];
    expect(edges, isNotEmpty);
    for (final w in edges) {
      expect(w, lessThanOrEqualTo(2), reason: 'a line, not a strip over the content');
    }
    expect(tester.getRect(find.text('Selection')).left, greaterThanOrEqualTo(panel.left));
    // Drag it 80 px further out, with frames as the mouse moves.
    final g = await tester.startGesture(panel.centerLeft + const Offset(3, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(-10, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SlideTransition)).width, closeTo(380, 20));
  });

  testWidgets('splitters stop at the minimum panel size', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inner = SplitNode(axis: SplitAxis.horizontal, ratio: 0.3, a: ContainerNode(panelIds: ['l']), b: ContainerNode(panelIds: ['c']));
    final outer = SplitNode(axis: SplitAxis.horizontal, ratio: 0.7, a: inner, b: ContainerNode(panelIds: ['r']));
    late DockStyle style;
    Widget pane(String k) => SizedBox.expand(key: ValueKey(k));
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 1000,
          height: 300,
          child: Builder(builder: (context) {
            style = DockStyle.fromTheme(context);
            return SplitView(
              node: outer,
              style: style,
              aBuilder: SplitView(node: inner, style: style, aBuilder: pane('left'), bBuilder: pane('centre')),
              bBuilder: pane('right'),
            );
          }),
        ),
      ),
    );
    Future<void> drag(Offset from, double dx) async {
      final g = await tester.startGesture(from);
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(dx / 20, 0));
        await tester.pump();
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    double w(String k) => tester.getSize(find.byKey(ValueKey(k))).width;
    // Right divider far to the left: centre and left stop at the minimum.
    await drag(tester.getTopRight(find.byKey(const ValueKey('centre'))) + const Offset(4, 100), -900);
    expect(w('centre'), greaterThanOrEqualTo(style.minPanelWidth - 0.5));
    expect(w('left'), greaterThanOrEqualTo(style.minPanelWidth - 0.5));
    // ...and far to the right: the right panel stops at the minimum.
    await drag(tester.getTopRight(find.byKey(const ValueKey('centre'))) + const Offset(4, 100), 900);
    expect(w('right'), closeTo(style.minPanelWidth, 0.5));
  });

  testWidgets('neighbours squeezed by a drag grow back when dragging back', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final inner = SplitNode(axis: SplitAxis.horizontal, ratio: 0.5, a: ContainerNode(panelIds: ['l']), b: ContainerNode(panelIds: ['c']));
    final outer = SplitNode(axis: SplitAxis.horizontal, ratio: 0.7, a: inner, b: ContainerNode(panelIds: ['r']));
    Widget pane(String k) => SizedBox.expand(key: ValueKey(k));
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 1000,
          height: 300,
          child: Builder(builder: (context) {
            final style = DockStyle.fromTheme(context);
            return SplitView(
              node: outer,
              style: style,
              aBuilder: SplitView(node: inner, style: style, aBuilder: pane('left'), bBuilder: pane('centre')),
              bBuilder: pane('right'),
            );
          }),
        ),
      ),
    );
    double w(String k) => tester.getSize(find.byKey(ValueKey(k))).width;
    final left = w('left'), centre = w('centre');

    // One drag: far left (centre at its minimum, left squeezed), then back.
    final g = await tester.startGesture(tester.getTopRight(find.byKey(const ValueKey('centre'))) + const Offset(4, 100));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(-30, 0));
      await tester.pump();
    }
    expect(w('left'), lessThan(left - 50));
    for (var i = 0; i < 20; i++) {
      await g.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(w('left'), closeTo(left, 1));
    expect(w('centre'), closeTo(centre, 1));
  });

  testWidgets('an opened flyout is focused, its header coloured, its content padded', (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final reg = DockPanelRegistry()
      ..register(DockPanelSpec(id: 'main', title: 'Main', builder: (_) => const Text('main')))
      ..register(DockPanelSpec(id: 'insp', title: 'Inspector', position: DockSide.right, builder: (_) => const Text('insp')))
      ..register(DockPanelSpec(
          id: 'tight',
          title: 'Tight',
          position: DockSide.right,
          flyoutPadding: EdgeInsets.zero,
          builder: (_) => const Text('tight')));
    final layout = DockLayout(root: ContainerNode(panelIds: ['main']), registry: reg)
      ..focusedPanelId = 'main'
      ..autoHide('insp', side: AutoSide.right)
      ..autoHide('tight', side: AutoSide.right);
    late DockStyle style;
    await tester.pumpWidget(app(Builder(builder: (context) {
      style = DockStyle.fromTheme(context);
      return DockAds(layout: layout);
    })));
    await tester.tap(find.text('Inspector'));
    await tester.pumpAndSettle();
    expect(layout.focusedPanelId, 'insp');
    final flyout = tester.widget<AutoHideFlyout>(find.byType(AutoHideFlyout));
    expect(flyout.isFocused, isTrue);
    final header = find.ancestor(of: find.text('Inspector').last, matching: find.byType(Container)).first;
    expect(tester.widget<Container>(header).color, style.tabFocusedActiveBackground);
    // Default padding around the content.
    final content = tester.getTopLeft(find.text('insp'));
    final box = tester.getTopLeft(find.ancestor(of: find.text('insp'), matching: find.byType(Padding)).first);
    expect(content - box, Offset(style.flyoutContentPadding.left, style.flyoutContentPadding.top));

    // A panel can set its own padding.
    await tester.tapAt(const Offset(100, 300)); // closes the flyout
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tight'));
    await tester.pumpAndSettle();
    expect(tester.widget<AutoHideFlyout>(find.byType(AutoHideFlyout)).contentPadding, EdgeInsets.zero);
  });
}
