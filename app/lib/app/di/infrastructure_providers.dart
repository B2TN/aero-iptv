import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../design_system/components/poster_image.dart';
import '../platform/api_key_store.dart';
import '../platform/device_profile.dart';
import '../platform/web_page.dart';

const Duration _connectTimeout = Duration(seconds: 15);

/// Ces services sont créés au démarrage, puis injectés dans `ProviderScope`.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('Base non injectée.'),
);
final deviceProfileProvider = Provider<DeviceProfile>(
  (ref) => throw StateError('Profil non injecté.'),
);
final credentialStoreProvider = Provider<CredentialStore>(
  (ref) => throw StateError('Coffre non injecté.'),
);
final apiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => const MemorylessApiKeyStore(),
);

/// Ouvre une adresse dans le navigateur. Répond `false` s'il n'y en a pas.
final webPageOpenerProvider = Provider<Future<bool> Function(String url)>(
  (ref) => openWebPage,
);
final posterCacheProvider = Provider<PosterCache>(
  (ref) => throw StateError('Cache non injecté.'),
);

final httpClientProvider = Provider<http.Client>((ref) {
  // Un serveur éteint doit échouer vite, même si un catalogue peut mettre deux
  // minutes à arriver une fois la connexion établie.
  final client = IOClient(HttpClient()..connectionTimeout = _connectTimeout);
  ref.onDispose(client.close);
  return client;
});
