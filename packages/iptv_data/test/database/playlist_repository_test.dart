import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';

/// Coffre qui refuse toute écriture, comme un Keystore en panne.
final class _BrokenVault implements CredentialStore {
  static const VaultFailure failure = VaultFailure(
    'panne',
    cause: 'ProviderException',
  );

  @override
  Future<PlaylistCredentials?> read(int sourceId) async => null;

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async =>
      throw failure;

  @override
  Future<void> delete(int sourceId) async {}
}

const M3uCredentials _credentials = M3uCredentials(
  playlistUrl: 'http://s.example/liste.m3u',
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(setup: configureConnection),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  Future<int> sources() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM sources')
        .getSingle();
    return row.read<int>('n');
  }

  test('ajoute une source et range ses identifiants', () async {
    final vault = MemoryCredentialStore();

    final result = await PlaylistRepositoryImpl(
      db,
      vault,
    ).add(name: 'Essai', credentials: _credentials);

    final source = (result as Ok<PlaylistSource>).value;
    expect(await vault.read(source.id), _credentials);
    expect(await sources(), 1);
  });

  test(
    'ne garde pas une source dont le coffre a refusé les identifiants',
    () async {
      final result = await PlaylistRepositoryImpl(
        db,
        _BrokenVault(),
      ).add(name: 'Essai', credentials: _credentials);

      expect((result as Err<PlaylistSource>).failure, _BrokenVault.failure);
      // Elle ne pourrait jamais être importée.
      expect(await sources(), 0);
    },
  );

  test('signale un coffre qui refuse une correction', () async {
    final added = await PlaylistRepositoryImpl(
      db,
      MemoryCredentialStore(),
    ).add(name: 'Essai', credentials: _credentials);
    final source = (added as Ok<PlaylistSource>).value;

    final result = await PlaylistRepositoryImpl(
      db,
      _BrokenVault(),
    ).update(source, credentials: _credentials);

    expect((result as Err<void>).failure, _BrokenVault.failure);
  });
}
