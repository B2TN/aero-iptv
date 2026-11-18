import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/app/daily_sync.dart';
import 'package:aero_iptv/app/di/infrastructure_providers.dart';
import 'package:aero_iptv/app/di/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

final DateTime _now = DateTime(2026, 11, 18, 9);

PlaylistSource _source({required DateTime lastSyncedAt}) => PlaylistSource(
  id: 1,
  name: 'Essai',
  kind: SourceKind.xtream,
  lastSyncedAt: lastSyncedAt,
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

/// Compte les synchronisations, sans jamais les finir : une seconde demande
/// trouve donc la première en cours.
final class _Importer implements CatalogImporter {
  final List<bool> fulls = [];

  @override
  Stream<ImportProgress> run(
    PlaylistSource source,
    PlaylistCredentials credentials, {
    bool full = false,
  }) async* {
    fulls.add(full);
    yield const ImportProgress(ImportStage.catalog);
  }
}

void main() {
  late _Importer importer;

  ProviderContainer containerWith(
    PlaylistSource source, {
    AppSettings settings = const AppSettings(catalogRules: catalogRulesVersion),
  }) {
    importer = _Importer();
    final container = ProviderContainer(
      overrides: [
        screenAwakeProvider.overrideWithValue(({required enabled}) async {}),
        settingsRepositoryProvider.overrideWithValue(_Settings(settings)),
        importPlaylistProvider.overrideWithValue(
          ImportPlaylist(_Vault(), importer),
        ),
        activeSourceProvider.overrideWithValue(source),
        clockProvider.overrideWithValue(() => _now),
      ],
    );
    addTearDown(container.dispose);
    // Le contrôleur écoute les lecteurs dès sa création.
    container.read(dailySyncProvider);
    return container;
  }

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('part au premier lancement du jour, sans tout remplacer', () async {
    final container = containerWith(
      _source(lastSyncedAt: DateTime(2026, 11, 17, 23)),
    );

    await container.read(dailySyncProvider.notifier).check(atLaunch: true);
    await settle();

    expect(importer.fulls, [false]);
    expect(container.read(importControllerProvider).running, isTrue);
  });

  test('pas deux fois le même jour', () async {
    final container = containerWith(
      _source(lastSyncedAt: DateTime(2026, 11, 18, 7)),
    );

    await container.read(dailySyncProvider.notifier).check(atLaunch: true);
    await settle();

    expect(importer.fulls, isEmpty);
  });

  test('application ouverte, repart après 24 h', () async {
    final container = containerWith(
      _source(lastSyncedAt: _now.subtract(const Duration(hours: 25))),
    );

    await container.read(dailySyncProvider.notifier).check();
    await settle();

    expect(importer.fulls, [false]);
  });

  test('attend la fermeture du lecteur', () async {
    final container = containerWith(
      _source(lastSyncedAt: DateTime(2026, 11, 17, 23)),
    );
    final players = container.read(openPlayersProvider.notifier)..opened();

    await container.read(dailySyncProvider.notifier).check(atLaunch: true);
    await settle();
    expect(importer.fulls, isEmpty);

    // L'épisode suivant ouvre son lecteur avant que le premier se ferme.
    players
      ..opened()
      ..closed();
    await settle();
    expect(importer.fulls, isEmpty);

    players.closed();
    await settle();
    expect(importer.fulls, [false]);
  });

  test('le réglage coupé l empêche', () async {
    final container = containerWith(
      _source(lastSyncedAt: DateTime(2026, 11, 10)),
      settings: const AppSettings(
        catalogRules: catalogRulesVersion,
        dailySync: false,
      ),
    );

    await container.read(dailySyncProvider.notifier).check(atLaunch: true);
    await settle();

    expect(importer.fulls, isEmpty);
  });

  test('une synchronisation en cours n en lance pas une autre', () async {
    final container = containerWith(
      _source(lastSyncedAt: DateTime(2026, 11, 10)),
    );
    final daily = container.read(dailySyncProvider.notifier);

    await daily.check(atLaunch: true);
    await settle();
    await daily.check();
    await settle();

    expect(importer.fulls, hasLength(1));
  });
}
