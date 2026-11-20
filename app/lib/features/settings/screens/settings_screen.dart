import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/trends.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/info_sheet.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_memory.dart';
import '../../../l10n/country_names.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../tutorial/tutorial_screen.dart';
import '../../updates/release_notes_screen.dart';
import '../../updates/update_controller.dart';
import '../playlist/playlist_manager_screen.dart';
import '../settings_actions.dart';
import '../widgets/setting_row.dart';
import 'subtitle_appearance_screen.dart';

/// Retards proposés, en secondes.
const List<int> _delays = [0, 2, 4, 6, 8, 10, 15, 20, 30];

/// Formulaire de signalement d'un problème, sur GitHub.
const String _bugReportPage =
    'https://github.com/B2TN/aero-iptv/issues/new?template=bug.yml';

/// Ligne de réglage : son libellé, sa valeur, et ce qu'elle fait.
typedef _Row = ({
  String label,
  String value,
  VoidCallback action,
  bool? toggled,
});

/// Catégorie des Paramètres, avec ses réglages.
typedef _Category = ({String title, IconData icon, List<_Row> rows});

/// Vrai quand le focus est dans les réglages d'une catégorie : Retour revient
/// alors à la liste des catégories, au lieu de quitter les Paramètres.
class SettingsPane extends Notifier<bool> {
  @override
  bool build() => false;

  void opened() => state = true;

  void close() => state = false;
}

final settingsPaneProvider = NotifierProvider<SettingsPane, bool>(
  SettingsPane.new,
);

/// Durée d'une étape ou d'une synchronisation, à la seconde.
String durationLabel(AppLocalizations l10n, Duration duration) {
  final seconds = (duration.inMilliseconds / 1000).round();
  return seconds < 60
      ? l10n.syncDurationSeconds(seconds)
      : l10n.syncDurationMinutes(seconds ~/ 60, seconds % 60);
}

/// Paramètres : les catégories à gauche, les réglages de la catégorie choisie
/// à droite.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FocusNode _categoriesNode = FocusNode(debugLabel: 'SettingsCategories');
  final FocusNode _rowsNode = FocusNode(debugLabel: 'SettingsRows');
  late int _category = ref
      .read(focusMemoryProvider)
      .read('settings.categories');

  @override
  void dispose() {
    _categoriesNode.dispose();
    _rowsNode.dispose();
    super.dispose();
  }

  Future<void> _chooseDelay() async {
    final l10n = context.l10n;
    final choice = await showAeroMenu(
      context,
      title: l10n.settingsDelay,
      options: [for (final delay in _delays) l10n.settingsDelayValue(delay)],
    );
    if (choice == null) return;
    updateSettings(
      ref,
      (settings) => settings.copyWith(liveDelaySeconds: _delays[choice]),
    );
  }

  /// « Automatique » suit le pays de l'adresse IP, redemandé à ce moment.
  Future<void> _chooseTrendCountry() async {
    final l10n = context.l10n;
    final language = ref.read(settingsProvider).languageCode;
    final codes = knownCountryCodes.toList(growable: false);
    final automatic = ref.read(automaticRegionProvider);
    final choice = await showAeroMenu(
      context,
      title: l10n.settingsTrendCountry,
      options: [
        l10n.settingsTrendCountryAuto(
          countryName(automatic, language) ?? automatic,
        ),
        for (final code in codes) countryName(code, language) ?? code,
      ],
    );
    if (choice == null) return;
    await ref
        .read(trendsProvider.notifier)
        .choose(choice == 0 ? null : codes[choice - 1]);
  }

  /// Une mise à jour trouvée ouvre ses notes ; sinon, le résultat s'affiche.
  Future<void> _checkUpdates() async {
    final found = await ref.read(updateControllerProvider.notifier).check();
    if (!mounted) return;
    final l10n = context.l10n;
    final release = ref.read(updateControllerProvider).release;
    if (found == true && release != null) {
      await openReleaseNotes(context, release);
      return;
    }
    await showInfoSheet(
      context,
      title: l10n.settingsVersion,
      closeLabel: l10n.actionClose,
      notes: [
        found == false ? l10n.settingsUpToDate : l10n.settingsUpdateCheckFailed,
      ],
    );
  }

  Future<void> _showSyncReport(SyncReport report) {
    final l10n = context.l10n;
    String phase(SyncPhase phase) => switch (phase) {
      SyncPhase.connection => l10n.syncPhaseConnection,
      SyncPhase.catalog => l10n.syncPhaseCatalog,
      SyncPhase.live => l10n.syncPhaseLive,
      SyncPhase.movies => l10n.syncPhaseMovies,
      SyncPhase.series => l10n.syncPhaseSeries,
      SyncPhase.refinement => l10n.syncPhaseRefinement,
      SyncPhase.update => l10n.syncPhaseUpdate,
      SyncPhase.guide => l10n.syncPhaseGuide,
    };
    String details(SyncStep step) => switch (step.phase) {
      SyncPhase.guide when step.received > 0 => l10n.syncReportProgrammes(
        step.received,
      ),
      _ when step.received > 0 => l10n.syncReportCounts(
        step.received,
        step.changed,
      ),
      _ => '',
    };
    return showInfoSheet(
      context,
      title: l10n.settingsLastSync,
      subtitle: [
        _syncDate(report.finishedAt),
        report.full ? l10n.syncReportFull : l10n.syncReportChanges,
      ].join(', '),
      closeLabel: l10n.actionClose,
      rows: [
        for (final step in report.steps)
          (
            phase(step.phase),
            [
              durationLabel(l10n, step.duration),
              if (details(step) case final text when text.isNotEmpty) text,
            ].join(', '),
          ),
        (l10n.syncReportTotal, durationLabel(l10n, report.total)),
      ],
    );
  }

  String _syncDate(DateTime date) =>
      DateFormat.MMMd(context.l10n.localeName).add_Hm().format(date);

  Future<void> _showLicenses() {
    final l10n = context.l10n;
    return showInfoSheet(
      context,
      title: l10n.settingsLicenses,
      closeLabel: l10n.actionClose,
      notes: [
        l10n.licensesFree,
        l10n.settingsAttribution,
        l10n.licensesTvMaze,
        l10n.licensesSegments,
        l10n.licensesCharts,
      ],
    );
  }

  List<_Category> _categories() {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final deepL = deepLKeyService(l10n);
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final activeId = ref.watch(activeSourceProvider)?.id;
    // Lu dans la liste : le relevé arrive après la synchronisation elle-même.
    final report = sources
        .where((source) => source.id == activeId)
        .firstOrNull
        ?.lastSyncReport;
    String onOff(bool value) => value ? l10n.settingsOn : l10n.settingsOff;
    final performance = ref.watch(lookProvider).isPerformance;
    final trendCountry = settings.trendCountry;
    final automatic = ref.watch(automaticRegionProvider);
    final version = ref.watch(appVersionProvider);
    _Row toggle(
      String label,
      bool value,
      AppSettings Function(AppSettings) change,
    ) => (
      label: label,
      value: onOff(value),
      action: () => updateSettings(ref, change),
      toggled: value,
    );
    return [
      (
        title: l10n.settingsCategoryPlaylist,
        icon: Icons.playlist_play_rounded,
        rows: [
          (
            label: l10n.settingsPlaylists,
            value: l10n.settingsPlaylistCount(sources.length),
            action: () => openPlaylistManager(context),
            toggled: null,
          ),
          toggle(
            l10n.settingsDailySync,
            settings.dailySync,
            (current) => current.copyWith(dailySync: !current.dailySync),
          ),
          (
            label: l10n.settingsLastSync,
            value: report == null
                ? l10n.settingsLastSyncNever
                : l10n.settingsLastSyncValue(
                    _syncDate(report.finishedAt),
                    durationLabel(l10n, report.total),
                  ),
            action: () {
              if (report != null) _showSyncReport(report);
            },
            toggled: null,
          ),
        ],
      ),
      (
        title: l10n.settingsCategoryCatalog,
        icon: Icons.video_library_rounded,
        rows: [
          toggle(
            l10n.settingsGroupSeries,
            settings.groupSeries,
            (current) => current.copyWith(groupSeries: !current.groupSeries),
          ),
          toggle(
            l10n.settingsGroupMovies,
            settings.groupMovies,
            (current) => current.copyWith(groupMovies: !current.groupMovies),
          ),
          toggle(
            l10n.settingsGroupChannels,
            settings.groupChannels,
            (current) =>
                current.copyWith(groupChannels: !current.groupChannels),
          ),
          (
            label: l10n.settingsTrendCountry,
            value: trendCountry == null
                ? l10n.settingsTrendCountryAuto(
                    countryName(automatic, settings.languageCode) ?? automatic,
                  )
                : countryName(trendCountry, settings.languageCode) ??
                      trendCountry,
            action: _chooseTrendCountry,
            toggled: null,
          ),
        ],
      ),
      (
        title: l10n.settingsCategoryPlayback,
        icon: Icons.play_circle_rounded,
        rows: [
          (
            label: l10n.settingsDelay,
            value: l10n.settingsDelayValue(settings.liveDelaySeconds),
            action: _chooseDelay,
            toggled: null,
          ),
        ],
      ),
      (
        title: l10n.settingsCategorySubtitles,
        icon: Icons.subtitles_rounded,
        rows: [
          (
            label: l10n.settingsSubtitleAppearance,
            value: [
              subtitleSizeName(l10n, settings.subtitleStyle.size),
              subtitleColorName(l10n, settings.subtitleStyle.color),
            ].join(', '),
            action: () => openSubtitleAppearance(context),
            toggled: null,
          ),
          (
            label: deepL.title,
            value: ref.watch(deepL.key) != null
                ? l10n.settingsKeySet
                : l10n.settingsKeyUnset,
            action: () => editApiKey(context, ref, deepL),
            toggled: null,
          ),
        ],
      ),
      (
        title: l10n.settingsCategoryAppearance,
        icon: Icons.palette_rounded,
        rows: [
          (
            label: l10n.settingsLanguage,
            value:
                languageNames[settings.languageCode] ?? settings.languageCode,
            action: () => chooseLanguage(context, ref),
            toggled: null,
          ),
          (
            label: l10n.settingsPerformance,
            // Sans choix de l'utilisateur, l'appareil a décidé : on le dit.
            value: settings.performanceMode == null
                ? l10n.settingsPerformanceAuto(onOff(performance))
                : onOff(performance),
            action: () => updateSettings(
              ref,
              (current) => current.copyWith(performanceMode: !performance),
            ),
            toggled: performance,
          ),
        ],
      ),
      (
        title: l10n.settingsCategoryUpdates,
        icon: Icons.system_update_rounded,
        rows: [
          (
            label: l10n.settingsVersion,
            value: version == null ? l10n.settingsVersionDev : '$version',
            action: _checkUpdates,
            toggled: null,
          ),
          (
            label: l10n.settingsBetaUpdates,
            value: onOff(settings.betaUpdates),
            action: () async {
              final repository = ref.read(settingsRepositoryProvider);
              final current = await repository.watch().first;
              await repository.save(
                current.copyWith(betaUpdates: !current.betaUpdates),
              );
              // Le bandeau suit le réglage aussitôt.
              await ref.read(updateControllerProvider.notifier).check();
            },
            toggled: settings.betaUpdates,
          ),
        ],
      ),
      (
        title: l10n.settingsCategoryAbout,
        icon: Icons.info_rounded,
        rows: [
          (
            label: l10n.settingsTutorial,
            value: '',
            action: () => openTutorial(context),
            toggled: null,
          ),
          (
            label: l10n.settingsReportProblem,
            value: '',
            action: () => openPageOrCode(
              context,
              ref,
              url: _bugReportPage,
              title: l10n.settingsReportProblem,
              hint: l10n.settingsReportScan,
            ),
            toggled: null,
          ),
          (
            label: l10n.settingsLicenses,
            value: '',
            action: _showLicenses,
            toggled: null,
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = _categories();
    final selected = _category.clamp(0, categories.length - 1);
    final rows = categories[selected].rows;
    // Retour depuis les réglages : la liste des catégories reprend le focus.
    ref.listen(settingsPaneProvider, (_, open) {
      if (!open && _rowsNode.hasFocus) _categoriesNode.requestFocus();
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(96, 32, 96, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsTitle, style: AeroText.title),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  height: categories.length * 60.0 + 32,
                  child: GlassPanel(
                    padding: const EdgeInsets.all(12),
                    child: DpadCollection.vertical(
                      autofocus: true,
                      focusNode: _categoriesNode,
                      memoryKey: 'settings.categories',
                      itemCount: categories.length,
                      itemExtent: 52,
                      padding: const EdgeInsets.all(4),
                      onIndexChanged: (index) =>
                          setState(() => _category = index),
                      // Valider une catégorie entre dans ses réglages.
                      onSelect: (index) {
                        setState(() => _category = index);
                        _rowsNode.requestFocus();
                      },
                      itemBuilder: (context, index, focused) => _CategoryLine(
                        title: categories[index].title,
                        icon: categories[index].icon,
                        focused: focused,
                        selected: index == selected,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: rows.length * 64.0 + 32,
                      child: GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: DpadCollection.vertical(
                          key: ValueKey(selected),
                          focusNode: _rowsNode,
                          memoryKey: 'settings.rows.$selected',
                          itemCount: rows.length,
                          itemExtent: 56,
                          padding: const EdgeInsets.all(4),
                          onFocusChange: (focused) {
                            final pane = ref.read(
                              settingsPaneProvider.notifier,
                            );
                            focused ? pane.opened() : pane.close();
                          },
                          onSelect: (index) => rows[index].action(),
                          itemBuilder: (context, index, focused) => SettingRow(
                            label: rows[index].label,
                            value: rows[index].value,
                            toggled: rows[index].toggled,
                            focused: focused,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Catégorie de la colonne de gauche : son icône et son nom. Celle qui est
/// affichée à droite reste marquée quand le focus est dans ses réglages.
class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.title,
    required this.icon,
    required this.focused,
    required this.selected,
  });

  final String title;
  final IconData icon;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = focused
        ? AeroColors.leaf
        : selected
        ? AeroColors.aqua
        : AeroColors.foam;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AeroText.heading.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
