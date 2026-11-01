import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../l10n/generated/app_localizations.dart';
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
    this.processed = 0,
    this.failure,
    this.epgFailed = false,
    this.finished = false,
  });

  final bool running;
  final int processed;
  final Failure? failure;
  final bool epgFailed;
  final bool finished;
}

/// Pilote l'import, en arrière-plan de l'interface.
class ImportController extends Notifier<ImportStatus> {
  StreamSubscription<ImportProgress>? _subscription;

  @override
  ImportStatus build() {
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    return const ImportStatus();
  }

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
    state = const ImportStatus(running: true);
    _subscription = ref
        .read(importPlaylistProvider)
        .call(source)
        .listen(
          (progress) {
            final done = progress.stage == ImportStage.done;
            state = ImportStatus(
              running: !done,
              finished: done,
              processed: progress.processed,
              epgFailed: progress.epgFailed,
            );
            if (done) unawaited(_rememberRules());
          },
          onError: (Object error) => state = ImportStatus(
            failure: error is Failure
                ? error
                : const StorageFailure('Import interrompu.'),
          ),
          cancelOnError: true,
        );
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportStatus>(ImportController.new);

/// Texte d'avancement de la synchronisation, ou `null` s'il n'y a rien à dire.
String? importMessage(AppLocalizations l10n, ImportStatus status) =>
    switch (status) {
      ImportStatus(running: true) => l10n.importRunning(status.processed),
      ImportStatus(failure: AuthFailure(status: final int status)) =>
        l10n.importAuthRejected(status),
      ImportStatus(failure: AuthFailure()) => l10n.importAuthFailed,
      ImportStatus(failure: ServerFailure(:final status)) =>
        l10n.importServerFailed(status),
      ImportStatus(failure: NetworkFailure()) => l10n.importNetworkFailed,
      ImportStatus(failure: ParseFailure()) => l10n.importFormatFailed,
      ImportStatus(failure: Failure()) => l10n.loadErrorTitle,
      ImportStatus(epgFailed: true) => l10n.importEpgFailed,
      ImportStatus(finished: true) => l10n.importDone,
      _ => null,
    };

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
