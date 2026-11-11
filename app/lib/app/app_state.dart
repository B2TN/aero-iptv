import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../l10n/generated/app_localizations.dart';
import 'di/infrastructure_providers.dart';
import 'di/repository_providers.dart';

/// Onglet affiché.
enum AppTab { home, live, search, settings }

class CurrentTab extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void show(AppTab tab) => state = tab;
}

final currentTabProvider = NotifierProvider<CurrentTab, AppTab>(CurrentTab.new);

final _settingsStreamProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Réglages courants. Les écrans lisent un champ avec `select`, pour ne se
/// reconstruire que si ce champ change.
final settingsProvider = Provider<AppSettings>(
  (ref) => ref.watch(_settingsStreamProvider).value ?? const AppSettings(),
);

/// Vrai une fois les réglages lus, pour éviter d'afficher la mauvaise langue.
final settingsReadyProvider = Provider<bool>(
  (ref) => ref.watch(_settingsStreamProvider).hasValue,
);

final sourcesProvider = StreamProvider<List<PlaylistSource>>(
  (ref) => ref.watch(playlistRepositoryProvider).watchSources(),
);

/// Playlist affichée.
final activeSourceProvider = Provider<PlaylistSource?>((ref) {
  final sources = ref.watch(sourcesProvider).value ?? const [];
  final activeId = ref.watch(
    settingsProvider.select((settings) => settings.activeSourceId),
  );
  for (final source in sources) {
    if (source.id == activeId) return source;
  }
  return sources.firstOrNull;
});

/// Enregistre une modification des réglages.
void updateSettings(
  WidgetRef ref,
  AppSettings Function(AppSettings current) change,
) => unawaited(
  ref.read(settingsRepositoryProvider).save(change(ref.read(settingsProvider))),
);

/// État de la synchronisation en cours.
final class ImportStatus {
  const ImportStatus({
    this.running = false,
    this.stage,
    this.section,
    this.processed = 0,
    this.failure,
    this.epgFailed = false,
    this.finished = false,
    this.failedSections = const {},
  });

  final bool running;

  /// Phase en cours. `null` tant qu'aucun import n'a commencé.
  final ImportStage? stage;

  /// Section en cours de réception, si la source en a plusieurs.
  final ContentKind? section;
  final int processed;
  final Failure? failure;
  final bool epgFailed;
  final bool finished;

  /// Sections que le serveur n'a pas livrées. Le reste du catalogue est à jour.
  final Map<ContentKind, Failure> failedSections;

  /// L'utilisateur doit en être informé, même une fois l'import terminé.
  bool get needsAttention =>
      running || failure != null || failedSections.isNotEmpty;
}

/// Pilote l'import, en arrière-plan de l'interface.
class ImportController extends Notifier<ImportStatus> {
  StreamSubscription<ImportProgress>? _subscription;

  @override
  ImportStatus build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const ImportStatus();
  }

  /// Un gros catalogue met plusieurs minutes à arriver sur un stick : l'écran
  /// de veille ne doit pas interrompre l'import.
  void _keepAwake(bool enabled) =>
      unawaited(ref.read(screenAwakeProvider)(enabled: enabled));

  /// Réimporte une fois le catalogue quand les règles de nettoyage ont changé :
  /// elles ne s'appliquent qu'à l'import, et l'utilisateur n'a pas à y penser.
  Future<void> refreshIfOutdated(PlaylistSource source) async {
    final settings = await ref.read(settingsRepositoryProvider).watch().first;
    if (settings.catalogRules < catalogRulesVersion) start(source);
  }

  Future<void> _rememberRules() async {
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.watch().first;
    await repository.save(settings.copyWith(catalogRules: catalogRulesVersion));
  }

  void start(PlaylistSource source) {
    if (state.running) return;
    state = const ImportStatus(running: true, stage: ImportStage.connecting);
    _keepAwake(true);
    _subscription = ref
        .read(importPlaylistProvider)
        .call(source)
        .listen(
          (progress) {
            final done = progress.stage == ImportStage.done;
            state = ImportStatus(
              running: !done,
              finished: done,
              stage: progress.stage,
              section: progress.section,
              processed: progress.processed,
              epgFailed: progress.epgFailed,
              failedSections: progress.failedSections,
            );
            if (!done) return;
            _keepAwake(false);
            unawaited(_rememberRules());
          },
          onError: (Object error) {
            _keepAwake(false);
            state = ImportStatus(
              failure: error is Failure
                  ? error
                  : const StorageFailure('Import interrompu.'),
            );
          },
          cancelOnError: true,
        );
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportStatus>(ImportController.new);

/// Texte d'avancement de la synchronisation, ou `null` s'il n'y a rien à dire.
String? importMessage(AppLocalizations l10n, ImportStatus status) =>
    switch (status) {
      ImportStatus(running: true) => _runningMessage(l10n, status),
      ImportStatus(:final Failure failure) => importFailureMessage(
        l10n,
        failure,
      ),
      ImportStatus(:final failedSections) when failedSections.isNotEmpty =>
        _partialMessage(l10n, failedSections),
      ImportStatus(epgFailed: true) => l10n.importEpgFailed,
      ImportStatus(finished: true) => l10n.importDone,
      _ => null,
    };

/// Cause d'un échec, avec le code du serveur quand il en a donné un.
String importFailureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      AuthFailure(status: final int status) => l10n.importAuthRejected(status),
      AuthFailure() => l10n.importAuthFailed,
      ServerFailure(:final status) => l10n.importServerFailed(status),
      NetworkFailure() => l10n.importNetworkFailed,
      ParseFailure() => l10n.importFormatFailed,
      _ => l10n.loadErrorTitle,
    };

/// Un import dure plusieurs minutes sur un stick : dire où il en est évite de
/// le croire bloqué.
String _runningMessage(AppLocalizations l10n, ImportStatus status) =>
    switch (status.stage) {
      ImportStage.connecting || null => l10n.importConnecting,
      ImportStage.catalog => switch (status.section) {
        ContentKind.live => l10n.importReceivingChannels(status.processed),
        ContentKind.movie => l10n.importReceivingMovies(status.processed),
        ContentKind.series => l10n.importReceivingSeries(status.processed),
        null => l10n.importRunning(status.processed),
      },
      ImportStage.indexing => l10n.importIndexing,
      ImportStage.epg || ImportStage.done => l10n.importGuide,
    };

String _partialMessage(
  AppLocalizations l10n,
  Map<ContentKind, Failure> failed,
) {
  final names = [
    for (final kind in failed.keys)
      switch (kind) {
        ContentKind.live => l10n.importSectionChannels,
        ContentKind.movie => l10n.importSectionMovies,
        ContentKind.series => l10n.importSectionSeries,
      },
  ];
  final cause = importFailureMessage(l10n, failed.values.first);
  return '${l10n.importPartial(names.join(', '))} $cause';
}

/// Oriente les tendances vers le pays de la playlist, ou celui de la langue.
String regionFor(PlaylistSource source, String language) {
  final country = source.defaultCountryCode;
  if (country != null && country.length == 2) return country;
  return switch (language) {
    'fr' => 'FR',
    'de' => 'DE',
    'es' => 'ES',
    'ar' => 'SA',
    _ => 'US',
  };
}

extension Localized on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
