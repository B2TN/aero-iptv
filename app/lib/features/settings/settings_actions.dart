import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_state.dart';
import '../../app/di/infrastructure_providers.dart';
import '../../app/di/repository_providers.dart';
import '../../design_system/components/aero_menu.dart';
import '../../design_system/components/qr_sheet.dart';
import '../../design_system/components/text_entry.dart';
import '../../l10n/country_names.dart';
import '../../l10n/generated/app_localizations.dart';

/// Page du compte où se trouve la clé d'API de DeepL.
const String _deepLKeysPage = 'https://www.deepl.com/your-account/keys';

/// Service dont l'utilisateur fournit lui-même la clé d'API.
typedef ApiKeyService = ({
  String name,
  String title,
  String page,
  NotifierProvider<ApiKeyController, String?> key,
});

/// DeepL, qui traduit les sous-titres.
ApiKeyService deepLKeyService(AppLocalizations l10n) => (
  name: 'DeepL',
  title: l10n.settingsDeepL,
  page: _deepLKeysPage,
  key: deepLKeyProvider,
);

/// Choix de la langue de l'application.
Future<void> chooseLanguage(BuildContext context, WidgetRef ref) async {
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

/// Saisie de la clé de [service]. Une clé déjà enregistrée se remplace ou se
/// retire.
Future<void> editApiKey(
  BuildContext context,
  WidgetRef ref,
  ApiKeyService service,
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
    physicalKeyboard: ref.read(physicalKeyboardProvider),
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

/// Sur PC, la page s'ouvre dans le navigateur. Une TV n'en a pas : la page est
/// proposée en QR code, à ouvrir sur un téléphone.
Future<void> _showKeyPage(
  BuildContext context,
  WidgetRef ref,
  ApiKeyService service,
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
