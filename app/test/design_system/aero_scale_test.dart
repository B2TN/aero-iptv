import 'package:aero_iptv/design_system/components/aero_canvas.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final window in const [
    Size(1280, 720),
    Size(1920, 1080),
    Size(3840, 2160),
    Size(1024, 768),
    Size(2560, 1080),
    Size(3840, 1080),
    Size(1920, 500),
    Size(900, 1400),
    Size(500, 500),
  ]) {
    testWidgets('le canevas remplit une fenêtre de $window', (tester) async {
      tester.view
        ..physicalSize = window
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AeroScale(child: SizedBox.expand(key: Key('contenu'))),
        ),
      );

      final area = tester.getRect(find.byKey(const Key('contenu')));
      expect(area.left, closeTo(0, 0.01));
      expect(area.top, closeTo(0, 0.01));
      expect(area.right, closeTo(window.width, 0.01));
      expect(area.bottom, closeTo(window.height, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('garde au moins 720 unités de haut', (tester) async {
    tester.view
      ..physicalSize = const Size(900, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late Size canvas;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AeroScale(
          child: LayoutBuilder(
            builder: (context, constraints) {
              canvas = constraints.biggest;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(canvas.width, 1100);
    expect(canvas.height, greaterThan(720));
  });

  testWidgets('supporte une fenêtre réduite à zéro', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 0,
          height: 0,
          child: AeroScale(child: SizedBox.expand()),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
