import 'package:aero_iptv/focus/dpad_collection.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(List<int>, List<int>)> _pump(WidgetTester tester) async {
  final selected = <int>[];
  final held = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 720)),
          child: Shortcuts(
            shortcuts: dpadShortcuts,
            child: Actions(
              actions: WidgetsApp.defaultActions,
              child: DpadCollection.horizontal(
                autofocus: true,
                itemCount: 3,
                itemExtent: 100,
                crossExtent: 100,
                onSelect: selected.add,
                onLongSelect: held.add,
                itemBuilder: (context, index, focused) => Text('$index'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return (selected, held);
}

void main() {
  testWidgets('un appui bref sélectionne l élément', (tester) async {
    final (selected, held) = await _pump(tester);

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.select,
      platform: 'android',
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select, platform: 'android');
    await tester.pump();

    expect(selected, [0]);
    expect(held, isEmpty);
  });

  testWidgets('un appui long ouvre le menu sans sélectionner', (tester) async {
    final (selected, held) = await _pump(tester);

    await tester.sendKeyEvent(
      LogicalKeyboardKey.arrowRight,
      platform: 'android',
    );
    await tester.pump();
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.select,
      platform: 'android',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select, platform: 'android');
    await tester.pump();

    expect(held, [1]);
    expect(selected, isEmpty);
  });

  testWidgets('le clic droit ouvre aussi le menu', (tester) async {
    final (selected, held) = await _pump(tester);

    await tester.tap(find.text('2'), buttons: kSecondaryButton);
    await tester.pump();

    expect(held, [2]);
    expect(selected, isEmpty);
  });
}
