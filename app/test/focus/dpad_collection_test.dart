import 'package:aero_iptv/focus/dpad_collection.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:aero_iptv/focus/focus_guard.dart';
import 'package:aero_iptv/focus/focus_memory.dart';
import 'package:aero_iptv/focus/focusable.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Environnement minimal avec les raccourcis de la télécommande.
Widget harness(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  ProviderContainer? container,
}) {
  final app = Directionality(
    textDirection: direction,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(1280, 720)),
      child: Shortcuts(
        shortcuts: dpadShortcuts,
        child: Actions(
          actions: WidgetsApp.defaultActions,
          child: FocusTraversalGroup(child: child),
        ),
      ),
    ),
  );
  return container == null
      ? ProviderScope(child: app)
      : UncontrolledProviderScope(container: container, child: app);
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump(const Duration(milliseconds: 200));
}

Widget label(int index, bool focused, List<String> log) => Builder(
  builder: (context) {
    if (focused) log.add('item$index');
    return Text('$index${focused ? '*' : ''}');
  },
);

void main() {
  testWidgets('déplace le focus dans une liste horizontale', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      harness(
        DpadCollection.horizontal(
          autofocus: true,
          itemCount: 10,
          itemExtent: 100,
          crossExtent: 100,
          onSelect: (_) {},
          itemBuilder: (context, index, focused) => label(index, focused, log),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('0*'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('2*'), findsOneWidget);
    expect(find.text('0*'), findsNothing);

    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.text('1*'), findsOneWidget);
  });

  testWidgets('une pression ne reconstruit que les éléments concernés', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      harness(
        DpadCollection.horizontal(
          autofocus: true,
          itemCount: 10,
          itemExtent: 100,
          crossExtent: 100,
          onSelect: (_) {},
          itemBuilder: (context, index, focused) {
            builds++;
            return Text('$index');
          },
        ),
      ),
    );
    await tester.pump();
    builds = 0;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(builds, 2);
  });

  testWidgets('la touche Select active l élément courant', (tester) async {
    int? selected;
    await tester.pumpWidget(
      harness(
        DpadCollection.vertical(
          autofocus: true,
          itemCount: 5,
          itemExtent: 40,
          onSelect: (index) => selected = index,
          itemBuilder: (context, index, focused) => Text('$index'),
        ),
      ),
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);

    expect(selected, 2);
  });

  testWidgets('quitte une liste par son extrémité', (tester) async {
    final button = FocusNode();
    addTearDown(button.dispose);
    await tester.pumpWidget(
      harness(
        Column(
          children: [
            Focusable(
              focusNode: button,
              onSelect: () {},
              builder: (context, focused) =>
                  const SizedBox(width: 100, height: 50, child: Text('haut')),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: DpadCollection.vertical(
                autofocus: true,
                itemCount: 3,
                itemExtent: 40,
                onSelect: (_) {},
                itemBuilder: (context, index, focused) => Text('$index'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowUp);

    expect(button.hasFocus, isTrue);
  });

  testWidgets('une grille se parcourt par lignes et colonnes', (tester) async {
    await tester.pumpWidget(
      harness(
        DpadCollection.grid(
          autofocus: true,
          itemCount: 7,
          columns: 3,
          itemExtent: 60,
          onSelect: (_) {},
          itemBuilder: (context, index, focused) =>
              Text('$index${focused ? '*' : ''}'),
        ),
      ),
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('3*'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('4*'), findsOneWidget);
    // La dernière ligne est incomplète : le focus se pose sur son dernier élément.
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('6*'), findsOneWidget);
  });

  testWidgets('inverse gauche et droite en arabe', (tester) async {
    await tester.pumpWidget(
      harness(
        direction: TextDirection.rtl,
        DpadCollection.horizontal(
          autofocus: true,
          itemCount: 5,
          itemExtent: 100,
          crossExtent: 100,
          onSelect: (_) {},
          itemBuilder: (context, index, focused) =>
              Text('$index${focused ? '*' : ''}'),
        ),
      ),
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowLeft);

    expect(find.text('1*'), findsOneWidget);
  });

  testWidgets('une liste vide ne prend pas le focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      harness(
        DpadCollection.vertical(
          focusNode: node,
          autofocus: true,
          itemCount: 0,
          itemExtent: 40,
          onSelect: (_) {},
          itemBuilder: (context, index, focused) => const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });

  testWidgets('garde un index valide quand la liste rétrécit', (tester) async {
    Widget list(int count) => harness(
      DpadCollection.vertical(
        autofocus: true,
        itemCount: count,
        itemExtent: 40,
        onSelect: (_) {},
        itemBuilder: (context, index, focused) =>
            Text('$index${focused ? '*' : ''}'),
      ),
    );
    await tester.pumpWidget(list(5));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(find.text('4*'), findsOneWidget);

    await tester.pumpWidget(list(2));
    await tester.pump();

    expect(find.text('1*'), findsOneWidget);
  });

  testWidgets('retrouve la position au retour sur une liste', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Widget list() => harness(
      container: container,
      DpadCollection.vertical(
        autofocus: true,
        memoryKey: 'test',
        itemCount: 5,
        itemExtent: 40,
        onSelect: (_) {},
        itemBuilder: (context, index, focused) =>
            Text('$index${focused ? '*' : ''}'),
      ),
    );
    await tester.pumpWidget(list());
    await tester.pump();
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(list());
    await tester.pump();

    expect(container.read(focusMemoryProvider).read('test'), 2);
    expect(find.text('2*'), findsOneWidget);
  });

  testWidgets('la souris déplace et active l élément', (tester) async {
    int? selected;
    await tester.pumpWidget(
      harness(
        DpadCollection.vertical(
          itemCount: 3,
          itemExtent: 40,
          onSelect: (index) => selected = index,
          itemBuilder: (context, index, focused) => Text('$index'),
        ),
      ),
    );
    await tester.tap(find.text('2'));
    await tester.pump();

    expect(selected, 2);
  });

  testWidgets('FocusGuard récupère un focus perdu', (tester) async {
    final safe = FocusNode(debugLabel: 'sûr');
    final doomed = FocusNode(debugLabel: 'condamné');
    addTearDown(safe.dispose);
    addTearDown(doomed.dispose);

    Widget screen({required bool withDoomed}) => harness(
      FocusGuard(
        fallback: () => safe,
        child: Column(
          children: [
            Focus(focusNode: safe, child: const SizedBox(height: 10)),
            if (withDoomed)
              Focus(
                focusNode: doomed,
                autofocus: true,
                child: const SizedBox(height: 10),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(screen(withDoomed: true));
    await tester.pump();
    expect(doomed.hasFocus, isTrue);

    await tester.pumpWidget(screen(withDoomed: false));
    await tester.pump();
    await tester.pump();

    expect(safe.hasFocus, isTrue);
  });

  testWidgets('un Focusable inactif est ignoré par le D-pad', (tester) async {
    final enabled = FocusNode();
    final disabled = FocusNode();
    addTearDown(enabled.dispose);
    addTearDown(disabled.dispose);
    await tester.pumpWidget(
      harness(
        Column(
          children: [
            Focusable(
              focusNode: enabled,
              autofocus: true,
              onSelect: () {},
              builder: (context, focused) =>
                  const SizedBox(width: 100, height: 40),
            ),
            Focusable(
              focusNode: disabled,
              builder: (context, focused) =>
                  const SizedBox(width: 100, height: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await press(tester, LogicalKeyboardKey.arrowDown);

    expect(disabled.hasFocus, isFalse);
    expect(enabled.hasFocus, isTrue);
  });
}
