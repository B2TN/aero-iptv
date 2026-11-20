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

/// Pays du réglage « Automatique » : celui de l'adresse IP, sinon la région
/// de l'appareil, sinon le pays de la langue de l'application.
String automaticRegion(AppSettings settings, String? systemRegion) =>
    settings.detectedCountry ??
    systemRegion ??
    switch (settings.languageCode) {
      'fr' => 'FR',
      'de' => 'DE',
      'es' => 'ES',
      'ar' => 'SA',
      _ => 'US',
    };

/// Pays des tendances : celui choisi dans les Paramètres, sinon le pays
/// automatique.
String trendRegion(AppSettings settings, String? systemRegion) =>
    settings.trendCountry ?? automaticRegion(settings, systemRegion);

final automaticRegionProvider = Provider<String>(
  (ref) => automaticRegion(
    ref.watch(settingsProvider),
    ref.watch(systemRegionProvider),
  ),
);

/// Pays des tendances de l'accueil.
final trendRegionProvider = Provider<String>(
  (ref) =>
      trendRegion(ref.watch(settingsProvider), ref.watch(systemRegionProvider)),
);

/// Tendances de l'accueil, actualisées en arrière-plan au plus une fois par
/// jour : l'accueil lit celles déjà enregistrées, sans attendre le réseau.
///
/// L'état compte les actualisations : l'accueil se recompose à chacune.
class Trends extends Notifier<int> {
  bool _running = false;

  /// Une demande est arrivée pendant l'actualisation, par exemple un autre
  /// pays : elle est traitée ensuite.
  bool _again = false;

  /// Le pays de l'adresse IP n'est demandé qu'une fois par lancement tant
  /// qu'il reste inconnu, par exemple hors ligne.
  bool _mayLocate = true;

  /// Langue de la dernière actualisation : les titres et les résumés des
  /// tendances sont dans cette langue.
  String? _language;

  @override
  int build() {
    ref.listen(trendRegionProvider, (_, _) => unawaited(check()));
    return 0;
  }

  /// Actualise les tendances si elles datent de la veille, si le pays a
  /// changé, ou si la langue a changé depuis la dernière fois : leurs titres
  /// et leurs résumés sont dans la langue demandée. Sans réseau, rien ne
  /// change : l'accueil garde les précédentes, ou l'ordre de la playlist.
  Future<void> check() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _locate();
        if (!ref.mounted) return;
        await _refresh();
      } while (_again && ref.mounted);
    } finally {
      _running = false;
    }
  }

  /// Choix des Paramètres : un pays, ou `null` pour « Automatique », qui
  /// redemande le pays de l'adresse IP : l'utilisateur a peut-être déménagé,
  /// ou changé de VPN.
  Future<void> choose(String? country) async {
    final settings = ref.read(settingsRepositoryProvider);
    final current = await settings.watch().first;
    await settings.save(
      current.copyWith(
        trendCountry: () => country,
        detectedCountry: country == null ? () => null : null,
      ),
    );
    if (country == null) _mayLocate = true;
    if (ref.mounted) await check();
  }

  /// Demande le pays de l'adresse IP, sauf si l'utilisateur en a choisi un ou
  /// s'il est déjà connu.
  Future<void> _locate() async {
    if (!_mayLocate) return;
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.watch().first;
    if (settings.trendCountry != null || settings.detectedCountry != null) {
      return;
    }
    _mayLocate = false;
    try {
      final country = await ref.read(countryLocatorProvider).country();
      final latest = await repository.watch().first;
      await repository.save(latest.copyWith(detectedCountry: () => country));
    } on Failure {
      return;
    }
  }

  /// Les réglages sont relus dans la base : le pays qui vient d'y être
  /// enregistré n'a pas encore atteint les écrans.
  Future<void> _refresh() async {
    final settings = await ref.read(settingsRepositoryProvider).watch().first;
    if (!ref.mounted) return;
    final region = trendRegion(settings, ref.read(systemRegionProvider));
    final language = settings.languageCode;
    final force = _language != null && _language != language;
    _language = language;
    try {
      final refreshed = await ref.read(refreshTrendingProvider)(
        region,
        language: language,
        force: force,
      );
      if (refreshed && ref.mounted) state++;
    } on Failure {
      return;
    }
  }
}

final trendsProvider = NotifierProvider<Trends, int>(Trends.new);
