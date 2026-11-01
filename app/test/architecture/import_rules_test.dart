import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fait respecter les frontières que le compilateur ne peut pas vérifier.
void main() {
  final imports = RegExp("^import '([^']+)'", multiLine: true);

  Iterable<File> dartFiles(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  Iterable<String> violations(String path, List<String> forbidden) sync* {
    for (final file in dartFiles(path)) {
      for (final match in imports.allMatches(file.readAsStringSync())) {
        final target = match[1]!;
        if (forbidden.any(target.startsWith)) yield '${file.path} : $target';
      }
    }
  }

  test('les écrans ne connaissent que le domaine', () {
    expect(
      violations('lib/features', const [
        'package:iptv_data',
        'package:iptv_player',
        'package:drift',
        'package:media_kit',
      ]),
      isEmpty,
    );
  });

  test('le design system ignore les écrans', () {
    expect(
      violations('lib/design_system', const [
        'package:iptv_data',
        'package:iptv_player',
        '../../features',
      ]),
      isEmpty,
    );
  });

  test('le moteur de focus ignore les écrans', () {
    expect(violations('lib/focus', const ['../features']), isEmpty);
  });

  test('aucun flou en temps réel dans l interface', () {
    final blurs = [
      for (final file in dartFiles('lib'))
        if (RegExp(
          r'\b(BackdropFilter|ImageFilter\.blur|ShaderMask)\b',
        ).hasMatch(file.readAsStringSync().replaceAll(RegExp(r'///.*'), '')))
          file.path,
    ];
    expect(blurs, isEmpty);
  });

  test('un seul onglet reste monté', () {
    final kept = [
      for (final file in dartFiles('lib/app'))
        if (file.readAsStringSync().contains('IndexedStack(')) file.path,
    ];
    expect(kept, isEmpty);
  });
}
