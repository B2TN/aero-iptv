import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_state.dart';
import '../../../app/di/infrastructure_providers.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/qr_sheet.dart';
import '../../../design_system/components/text_entry.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../l10n/country_names.dart';
import '../playlist/playlist_manager_screen.dart';
import '../widgets/setting_row.dart';

/// Pages des comptes où se trouvent les clés d'API.
const String _deepLKeysPage = 'https://www.deepl.com/your-account/keys';
const String _openSubtitlesKeysPage = 'https://www.opensubtitles.com/consumers';

/// Service dont l'utilisateur fournit lui-même la clé d'API.
typedef _KeyService = ({
  String name,
  String title,
  String page,
  NotifierProvider<ApiKeyController, String?> key,
});

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

  Future<void> _chooseLanguage(BuildContext context, WidgetRef ref) async {
    final codes = languageNames.keys.toList(growable: false);
    final choice = await showAeroMenu(
      context,
      title: context.l10n.settingsLanguage,
      options: languageNames.values.toList(growable: false),
    );
    if (choice == null) return;
    updateSettings(
      ref,
      (settings) => settings.copyWith(languageCode: codes[choice]),
    );
  }

  /// Sur PC, la page s'ouvre dans le navigateur. Une TV n'en a pas : la page est
  /// proposée en QR code, à ouvrir sur un téléphone.
  Future<void> _showKeyPage(
    BuildContext context,
    WidgetRef ref,
    _KeyService service,
  ) async {
    final l10n = context.l10n;
    if (await ref.read(webPageOpenerProvider)(service.page)) return;
    if (!context.mounted) return;
    await showQrSheet(
      context,
      title: l10n.settingsKeyGet,
      hint: l10n.settingsKeyScan(service.name),
      url: service.page,
      closeLabel: l10n.actionBack,
    );
  }

  Future<void> _editKey(
    BuildContext context,
    WidgetRef ref,
    _KeyService service,
  ) async {
    final l10n = context.l10n;
    final keys = ref.read(service.key.notifier);
    if (ref.read(service.key) != null) {
      final choice = await showAeroMenu(
        context,
        title: service.title,
        options: [l10n.settingsKeyReplace, l10n.settingsKeyRemove],
      );
      if (choice == null || !context.mounted) return;
      if (choice == 1) {
        await keys.save(null);
        return;
      }
    }
    final value = await showTextEntry(
      context,
      title: service.title,
      obscure: true,
      action: (
        label: l10n.settingsKeyGet,
        onSelect: () => _showKeyPage(context, ref, service),
      ),
    );
    final key = value?.trim() ?? '';
    if (key.isNotEmpty) await keys.save(key);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final _KeyService deepL = (
      name: 'DeepL',
      title: l10n.settingsDeepL,
      page: _deepLKeysPage,
      key: deepLKeyProvider,
    );
    final _KeyService openSubtitles = (
      name: 'OpenSubtitles',
      title: l10n.settingsOpenSubtitles,
      page: _openSubtitlesKeysPage,
      key: openSubtitlesKeyProvider,
    );
    final playlists = ref.watch(sourcesProvider).value?.length ?? 0;
    String onOff(bool value) => value ? l10n.settingsOn : l10n.settingsOff;
    String keyState(_KeyService service) => ref.watch(service.key) != null
        ? l10n.settingsKeySet
        : l10n.settingsKeyUnset;

    final rows = <({String label, String value, VoidCallback action})>[
      (
        label: l10n.settingsPlaylists,
        value: l10n.settingsPlaylistCount(playlists),
        action: () => openPlaylistManager(context),
      ),
      (
        label: l10n.settingsGroupSeries,
        value: onOff(settings.groupSeries),
        action: () => updateSettings(
          ref,
          (current) => current.copyWith(groupSeries: !current.groupSeries),
        ),
      ),
      (
        label: l10n.settingsGroupChannels,
        value: onOff(settings.groupChannels),
        action: () => updateSettings(
          ref,
          (current) => current.copyWith(groupChannels: !current.groupChannels),
        ),
      ),
      (
        label: l10n.settingsDelay,
        value: l10n.settingsDelayValue(settings.liveDelaySeconds),
        action: () => _chooseDelay(context, ref),
      ),
      (
        label: l10n.settingsLanguage,
        value: languageNames[settings.languageCode] ?? settings.languageCode,
        action: () => _chooseLanguage(context, ref),
      ),
      (
        label: deepL.title,
        value: keyState(deepL),
        action: () => _editKey(context, ref, deepL),
      ),
      (
        label: openSubtitles.title,
        value: keyState(openSubtitles),
        action: () => _editKey(context, ref, openSubtitles),
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
