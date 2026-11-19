import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import 'app_state.dart';
import 'di/repository_providers.dart';

final RegExp _countryCode = RegExp(r'^[A-Za-z]{2}$');

/// Région des réglages de langue et de région de l'appareil, si elle est
/// connue.
final systemRegionProvider = Provider<String?>((ref) {
  final code = PlatformDispatcher.instance.locale.countryCode;
  return code != null && _countryCode.hasMatch(code)
      ? code.toUpperCase()
      : null;
});

/// Pays des tendances de l'accueil : celui de l'appareil, sinon celui de la
/// langue de l'application.
final trendRegionProvider = Provider<String>((ref) {
  final language = ref.watch(
    settingsProvider.select((settings) => settings.languageCode),
  );
  return ref.watch(systemRegionProvider) ?? _regionOfLanguage(language);
});

String _regionOfLanguage(String language) => switch (language) {
  'fr' => 'FR',
  'de' => 'DE',
  'es' => 'ES',
  'ar' => 'SA',
  _ => 'US',
};

/// Tendances de l'accueil, actualisées en arrière-plan au plus une fois par
/// jour : l'accueil lit celles déjà enregistrées, sans attendre le réseau.
///
/// L'état compte les actualisations : l'accueil se recompose à chacune.
class Trends extends Notifier<int> {
  bool _running = false;

  /// Une demande est arrivée pendant l'actualisation, par exemple un autre
  /// pays : elle est traitée ensuite.
  bool _again = false;

  @override
  int build() {
    ref.listen(trendRegionProvider, (_, _) => unawaited(check()));
    return 0;
  }

  /// Actualise les tendances si elles datent de la veille, ou si le pays a
  /// changé. Sans réseau, rien ne change : l'accueil garde les précédentes,
  /// ou l'ordre de la playlist.
  Future<void> check() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _refresh();
      } while (_again && ref.mounted);
    } finally {
      _running = false;
    }
  }

  Future<void> _refresh() async {
    final region = ref.read(trendRegionProvider);
    final language = ref.read(settingsProvider).languageCode;
    try {
      final refreshed = await ref.read(refreshTrendingProvider)(
        region,
        language: language,
      );
      if (refreshed && ref.mounted) state++;
    } on Failure {
      return;
    }
  }
}

final trendsProvider = NotifierProvider<Trends, int>(Trends.new);
