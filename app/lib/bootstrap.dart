import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_player/iptv_player.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/aero_iptv_app.dart';
import 'app/di/infrastructure_providers.dart';
import 'app/platform/api_key_store.dart';
import 'app/platform/device_profile.dart';
import 'app/platform/platform_credential_store.dart';
import 'design_system/components/poster_image.dart';

/// Nombre maximal d'images gardées décodées en mémoire.
const int _maxDecodedImages = 150;

/// Prépare les services, puis retourne l'application prête à démarrer.
///
/// [dataDirectory] et [overrides] servent aux tests.
Future<Widget> bootstrap({
  Directory? dataDirectory,
  List<Override> overrides = const [],
}) async {
  initializePlaybackEngine();

  final profile = await DeviceProfile.detect();
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = profile.imageCacheBytes
    ..maximumSize = _maxDecodedImages;

  final directory = dataDirectory ?? await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final cacheDirectory = Directory(p.join(directory.path, 'posters'));
  await cacheDirectory.create(recursive: true);

  // SQLite reçoit son propre dossier temporaire, à côté de la base : sur
  // Android, il n'en trouve pas toujours un qu'il ait le droit d'utiliser.
  final scratchDirectory = Directory(p.join(directory.path, 'sqlite_tmp'));
  await _recreate(scratchDirectory);

  final database = AppDatabase(
    openAppDatabase(
      File(p.join(directory.path, 'aero_iptv.sqlite')),
      temporaryDirectory: scratchDirectory,
    ),
  );
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      deviceProfileProvider.overrideWithValue(profile),
      credentialStoreProvider.overrideWithValue(
        createCredentialStore(Directory(p.join(directory.path, 'vault'))),
      ),
      apiKeyStoreProvider.overrideWithValue(
        createApiKeyStore(Directory(p.join(directory.path, 'vault'))),
      ),
      posterCacheProvider.overrideWith(
        (ref) => PosterCache(cacheDirectory, ref.watch(httpClientProvider)),
      ),
      ...overrides,
    ],
  );
  unawaited(container.read(posterCacheProvider).trim());
  unawaited(_forgetRetiredKeys(container.read(apiKeyStoreProvider)));

  return UncontrolledProviderScope(
    container: container,
    child: const AeroIptvApp(),
  );
}

/// Vide [directory] : un arrêt brutal y laisse des fichiers temporaires que
/// rien ne reprendra.
Future<void> _recreate(Directory directory) async {
  try {
    if (directory.existsSync()) await directory.delete(recursive: true);
  } on FileSystemException {
    // Un fichier encore ouvert partira au prochain démarrage.
  }
  await directory.create(recursive: true);
}

/// Clés de services que l'application n'utilise plus : rien ne doit rester
/// dans le coffre sans raison.
Future<void> _forgetRetiredKeys(ApiKeyStore keys) async {
  try {
    await keys.write('opensubtitles', null);
  } on Exception {
    // Coffre ou fichier indisponible : nouvel essai au prochain démarrage.
  }
}
