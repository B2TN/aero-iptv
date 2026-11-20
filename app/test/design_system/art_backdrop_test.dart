import 'dart:async';
import 'dart:io';

import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/design_system/components/art_backdrop.dart';
import 'package:aero_iptv/design_system/components/poster_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Adresses des images affichées en ce moment.
List<String?> _shown(WidgetTester tester) => [
  for (final image in tester.widgetList<PosterImage>(find.byType(PosterImage)))
    image.url,
];

Future<void> _pump(WidgetTester tester, http.Client client) async {
  final directory = Directory.systemTemp.createTempSync('art_backdrop');
  addTearDown(() => directory.deleteSync(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        posterCacheProvider.overrideWithValue(PosterCache(directory, client)),
      ],
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: ArtBackdrop(
          imageUrls: ['https://img.example/large.jpg'],
          posterUrl: 'https://img.example/poster.jpg',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('une image large trop lente laisse place à l affiche', (
    tester,
  ) async {
    // Le serveur ne répond jamais pour l'image large.
    final never = Completer<http.Response>();
    await _pump(
      tester,
      MockClient(
        (request) => request.url.path == '/large.jpg'
            ? never.future
            : Future.value(http.Response('', 404)),
      ),
    );
    expect(_shown(tester), ['https://img.example/large.jpg']);

    await tester.pump(const Duration(seconds: 6));
    expect(_shown(tester), isNot(contains('https://img.example/large.jpg')));
    expect(_shown(tester), contains('https://img.example/poster.jpg'));
    // Le téléchargement abandonné finit par expirer.
    await tester.pump(const Duration(seconds: 13));
  });

  testWidgets('une image large cassée laisse place à l affiche', (
    tester,
  ) async {
    await _pump(tester, MockClient((request) async => http.Response('', 404)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_shown(tester), isNot(contains('https://img.example/large.jpg')));
    expect(_shown(tester), contains('https://img.example/poster.jpg'));
  });
}
