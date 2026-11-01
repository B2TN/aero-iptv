import 'dart:io';

import 'package:aero_iptv/app/platform/window_fullscreen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la fenêtre entre en plein écran et retrouve sa place', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    final fullscreen = WindowFullscreen();

    fullscreen.toggle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fullscreen.isActive, isTrue);

    fullscreen.toggle();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fullscreen.isActive, isFalse);
  }, skip: !Platform.isWindows);
}
