import 'package:aero_iptv/design_system/components/aero_button.dart';
import 'package:aero_iptv/focus/dpad_collection.dart';
import 'package:aero_iptv/focus/dpad_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1280, 720)),
          child: Shortcuts(
            shortcuts: dpadShortcuts,
            child: Actions(actions: WidgetsApp.defaultActions, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// OK maintenu, comme sur une télécommande : un appui, des répétitions, puis
/// le relâchement.
Future<void> _hold(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key, platform: 'android');
  for (var i = 0; i < 6; i++) {
    await tester.sendKeyRepeatEvent(key, platform: 'android');
  }
  await tester.sendKeyUpEvent(key, platform: 'android');
  await tester.pump();
}

void main() {
  for (final key in [LogicalKeyboardKey.select, LogicalKeyboardKey.enter]) {
    testWidgets('un bouton ne se valide qu une fois (${key.keyLabel})', (
      tester,
    ) async {
      var count = 0;
      await _pump(
        tester,
        AeroButton(label: 'Ouvrir', autofocus: true, onSelect: () => count++),
      );

      await _hold(tester, key);

      expect(count, 1);
    });
  }

  testWidgets('une liste sans menu ne se valide qu une fois', (tester) async {
    final selected = <int>[];
    await _pump(
      tester,
      DpadCollection.vertical(
        autofocus: true,
        itemCount: 3,
        itemExtent: 50,
        onSelect: selected.add,
        itemBuilder: (context, index, focused) => Text('$index'),
      ),
    );

    await _hold(tester, LogicalKeyboardKey.select);

    expect(selected, [0]);
  });
}
