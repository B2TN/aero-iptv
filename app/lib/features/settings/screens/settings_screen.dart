import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_state.dart';
import '../../../app/trends.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../l10n/country_names.dart';
import '../../tutorial/tutorial_screen.dart';
import '../playlist/playlist_manager_screen.dart';
import '../settings_actions.dart';
import '../widgets/setting_row.dart';
import 'subtitle_appearance_screen.dart';
import '../../updates/update_controller.dart';

/// Retards proposés, en secondes.
const List<int> _delays = [0, 2, 4, 6, 8, 10, 15, 20, 30];

/// Paramètres.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _chooseDelay(BuildContext context, WidgetRef ref) async {
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
  Future<void> _chooseTrendCountry(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final deepL = deepLKeyService(l10n);
    final playlists = ref.watch(sourcesProvider).value?.length ?? 0;
    String onOff(bool value) => value ? l10n.settingsOn : l10n.settingsOff;
    String keyState(ApiKeyService service) => ref.watch(service.key) != null
        ? l10n.settingsKeySet
        : l10n.settingsKeyUnset;

    final performance = ref.watch(lookProvider).isPerformance;
    final trendCountry = settings.trendCountry;
    final automatic = ref.watch(automaticRegionProvider);
    final rows =
        <({String label, String value, VoidCallback action, bool? toggled})>[
          (
            label: l10n.settingsPlaylists,
            value: l10n.settingsPlaylistCount(playlists),
            action: () => openPlaylistManager(context),
            toggled: null,
          ),
          (
            label: l10n.settingsDailySync,
            value: onOff(settings.dailySync),
            action: () => updateSettings(
              ref,
              (current) => current.copyWith(dailySync: !current.dailySync),
            ),
            toggled: settings.dailySync,
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
          (
            label: l10n.settingsGroupSeries,
            value: onOff(settings.groupSeries),
            action: () => updateSettings(
              ref,
              (current) => current.copyWith(groupSeries: !current.groupSeries),
            ),
            toggled: settings.groupSeries,
          ),
          (
            label: l10n.settingsGroupMovies,
            value: onOff(settings.groupMovies),
            action: () => updateSettings(
              ref,
              (current) => current.copyWith(groupMovies: !current.groupMovies),
            ),
            toggled: settings.groupMovies,
          ),
          (
            label: l10n.settingsGroupChannels,
            value: onOff(settings.groupChannels),
            action: () => updateSettings(
              ref,
              (current) =>
                  current.copyWith(groupChannels: !current.groupChannels),
            ),
            toggled: settings.groupChannels,
          ),
          (
            label: l10n.settingsDelay,
            value: l10n.settingsDelayValue(settings.liveDelaySeconds),
            action: () => _chooseDelay(context, ref),
            toggled: null,
          ),
          (
            label: l10n.settingsLanguage,
            value:
                languageNames[settings.languageCode] ?? settings.languageCode,
            action: () => chooseLanguage(context, ref),
            toggled: null,
          ),
          (
            label: l10n.settingsTrendCountry,
            value: trendCountry == null
                ? l10n.settingsTrendCountryAuto(
                    countryName(automatic, settings.languageCode) ?? automatic,
                  )
                : countryName(trendCountry, settings.languageCode) ??
                      trendCountry,
            action: () => _chooseTrendCountry(context, ref),
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
            value: keyState(deepL),
            action: () => editApiKey(context, ref, deepL),
            toggled: null,
          ),
          (
            label: l10n.settingsTutorial,
            value: '',
            action: () => openTutorial(context),
            toggled: null,
          ),
        ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(160, 32, 160, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.settingsTitle, style: AeroText.title),
          const SizedBox(height: 16),
          // Le panneau rétrécit si la place manque : la liste défile alors.
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: rows.length * 64.0 + 40,
                child: GlassPanel(
                  padding: const EdgeInsets.all(12),
                  child: DpadCollection.vertical(
                    autofocus: true,
                    memoryKey: 'settings.rows',
                    itemCount: rows.length,
                    itemExtent: 56,
                    padding: const EdgeInsets.all(4),
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
          Text(l10n.settingsAttribution, style: AeroText.caption),
        ],
      ),
    );
  }
}
