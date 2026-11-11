import 'dart:async';

import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

const PlaylistSource _source = PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
);

final class _Settings implements SettingsRepository {
  _Settings(this.current);

  AppSettings current;

  @override
  Stream<AppSettings> watch() => Stream.value(current);

  @override
  Future<void> save(AppSettings settings) async => current = settings;
}

final class _Vault implements CredentialStore {
  @override
  Future<PlaylistCredentials?> read(int sourceId) async =>
      const M3uCredentials(playlistUrl: 'http://s.example/liste.m3u');

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {}

  @override
  Future<void> delete(int sourceId) async {}
}

final class _Importer implements CatalogImporter {
  _Importer({this.failure});

  final Failure? failure;
  int runs = 0;

  @override
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials,
  ) async* {
    runs++;
    final error = failure;
    if (error != null) throw error;
    yield const ImportProgress(ImportStage.done);
  }
}

void main() {
  /// Demandes faites à l'écran : `true` pour le garder allumé.
  final awake = <bool>[];

  setUp(awake.clear);

  ProviderContainer containerWith(_Settings settings, _Importer importer) {
    final container = ProviderContainer(
      overrides: [
        screenAwakeProvider.overrideWithValue(
          ({required enabled}) async => awake.add(enabled),
        ),
        settingsRepositoryProvider.overrideWithValue(settings),
        importPlaylistProvider.overrideWithValue(
          ImportPlaylist(_Vault(), importer),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('réimporte une fois un catalogue aux anciennes règles', () async {
    final settings = _Settings(const AppSettings());
    final importer = _Importer();
    final container = containerWith(settings, importer);
    final controller = container.read(importControllerProvider.notifier);

    await controller.refreshIfOutdated(_source);
    await settle();
    await settle();
    await controller.refreshIfOutdated(_source);
    await settle();

    expect(importer.runs, 1);
    expect(settings.current.catalogRules, catalogRulesVersion);
  });

  test('garde l écran allumé le temps de l import', () async {
    final container = containerWith(
      _Settings(const AppSettings()),
      _Importer(),
    );

    container.read(importControllerProvider.notifier).start(_source);
    expect(awake, [true]);
    await settle();
    await settle();

    expect(awake, [true, false]);
  });

  test('rend l écran à la veille après un échec', () async {
    final container = containerWith(
      _Settings(const AppSettings()),
      _Importer(failure: const NetworkFailure('hors ligne')),
    );

    container.read(importControllerProvider.notifier).start(_source);
    await settle();
    await settle();

    expect(awake, [true, false]);
    expect(container.read(importControllerProvider).failure, isNotNull);
  });

  test('laisse tranquille un catalogue à jour', () async {
    final importer = _Importer();
    final container = containerWith(
      _Settings(const AppSettings(catalogRules: catalogRulesVersion)),
      importer,
    );

    await container
        .read(importControllerProvider.notifier)
        .refreshIfOutdated(_source);
    await settle();

    expect(importer.runs, 0);
  });

  test('un échec sera retenté au prochain démarrage', () async {
    final settings = _Settings(const AppSettings());
    final importer = _Importer(failure: const NetworkFailure('hors ligne'));
    final container = containerWith(settings, importer);

    await container
        .read(importControllerProvider.notifier)
        .refreshIfOutdated(_source);
    await settle();
    await settle();

    expect(container.read(importControllerProvider).failure, isNotNull);
    expect(settings.current.catalogRules, 0);
  });
}
