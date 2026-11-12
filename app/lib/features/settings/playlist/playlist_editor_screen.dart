import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/infrastructure_providers.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/text_entry.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_guard.dart';
import '../../../l10n/country_names.dart';
import '../widgets/setting_row.dart';

Future<void> openPlaylistEditor(BuildContext context, PlaylistSource? source) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => PlaylistEditorScreen(source: source),
      ),
    );

/// Ligne du formulaire.
typedef _Field = ({String label, String value, Future<void> Function() edit});

/// Ajout ou modification d'une playlist.
class PlaylistEditorScreen extends ConsumerStatefulWidget {
  const PlaylistEditorScreen({this.source, super.key});

  /// `null` crée une nouvelle playlist.
  final PlaylistSource? source;

  @override
  ConsumerState<PlaylistEditorScreen> createState() =>
      _PlaylistEditorScreenState();
}

class _PlaylistEditorScreenState extends ConsumerState<PlaylistEditorScreen> {
  final FocusNode _saveNode = FocusNode(debugLabel: 'SavePlaylist');
  late String _name = widget.source?.name ?? '';
  late SourceKind _kind = widget.source?.kind ?? SourceKind.m3u;
  late String? _country = widget.source?.defaultCountryCode;
  String _url = '';
  String _epgUrl = '';
  String _server = '';
  String _username = '';
  String _password = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    if (source != null) unawaited(_loadCredentials(source.id));
  }

  @override
  void dispose() {
    _saveNode.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials(int sourceId) async {
    final credentials = await ref.read(credentialStoreProvider).read(sourceId);
    if (!mounted) return;
    setState(() {
      switch (credentials) {
        case M3uCredentials():
          _url = credentials.playlistUrl;
          _epgUrl = credentials.epgUrl ?? '';
        case XtreamCredentials():
          _server = credentials.serverUrl;
          _username = credentials.username;
          _password = credentials.password;
        case null:
          break;
      }
    });
  }

  Future<void> _editText(
    String title,
    String current,
    void Function(String value) apply, {
    bool obscure = false,
  }) async {
    // Un champ masqué repart de zéro : la frappe s'ajouterait sinon à un texte
    // invisible. Le valider vide conserve donc sa valeur.
    final value = await showTextEntry(
      context,
      title: title,
      initial: obscure ? '' : current,
      obscure: obscure,
    );
    if (value == null || !mounted) return;
    final text = value.trim();
    if (obscure && text.isEmpty) return;
    setState(() => apply(text));
  }

  Future<void> _chooseKind() async {
    final l10n = context.l10n;
    final choice = await showAeroMenu(
      context,
      title: l10n.playlistType,
      options: const ['M3U', 'Xtream Codes'],
    );
    if (choice != null) setState(() => _kind = SourceKind.values[choice]);
  }

  Future<void> _chooseCountry() async {
    final l10n = context.l10n;
    final language = ref.read(settingsProvider).languageCode;
    final codes = knownCountryCodes.toList(growable: false);
    final choice = await showAeroMenu(
      context,
      title: l10n.playlistCountry,
      options: [
        l10n.playlistCountryNone,
        for (final code in codes) countryName(code, language) ?? code,
      ],
    );
    if (choice != null) {
      setState(() => _country = choice == 0 ? null : codes[choice - 1]);
    }
  }

  PlaylistCredentials? _credentials() => switch (_kind) {
    SourceKind.m3u when _url.isNotEmpty => M3uCredentials(
      playlistUrl: _url,
      epgUrl: _epgUrl.isEmpty ? null : _epgUrl,
    ),
    SourceKind.xtream when _server.isNotEmpty && _username.isNotEmpty =>
      XtreamCredentials(
        serverUrl: _server,
        username: _username,
        password: _password,
      ),
    _ => null,
  };

  /// Enregistre le formulaire. Retourne `null` s'il est incomplet.
  ///
  /// Chaque action du formulaire passe par ici : sinon, une correction serait
  /// perdue sans avertissement, et l'import repartirait des anciens identifiants.
  Future<PlaylistSource?> _persist() async {
    final credentials = _credentials();
    if (_name.isEmpty || credentials == null) {
      setState(() => _error = context.l10n.playlistMissingFields);
      return null;
    }
    final repository = ref.read(playlistRepositoryProvider);
    final existing = widget.source;
    if (existing == null) {
      final result = await repository.add(
        name: _name,
        credentials: credentials,
        defaultCountryCode: _country,
      );
      return switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => _reject(failure),
      };
    }
    final saved = PlaylistSource(
      id: existing.id,
      name: _name,
      kind: _kind,
      defaultCountryCode: _country,
      lastSyncedAt: existing.lastSyncedAt,
    );
    final result = await repository.update(saved, credentials: credentials);
    return result is Err<void> ? _reject(result.failure) : saved;
  }

  /// Un enregistrement refusé se dit : sinon l'écran resterait muet, et
  /// l'import partirait sans identifiants. La cause tient sur plusieurs lignes,
  /// que le formulaire n'a pas la place d'afficher.
  PlaylistSource? _reject(Failure failure) {
    if (!mounted) return null;
    final l10n = context.l10n;
    unawaited(
      showAeroOverlay<void>(
        context,
        label: l10n.playlistSaveFailedTitle,
        builder: (context) => AeroMessage(
          title: l10n.playlistSaveFailedTitle,
          body: importFailureMessage(l10n, failure),
          actionLabel: l10n.actionBack,
          onAction: () => Navigator.of(context).pop(),
        ),
      ),
    );
    return null;
  }

  void _setActive(PlaylistSource source) => updateSettings(
    ref,
    (settings) => settings.copyWith(activeSourceId: source.id),
  );

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final saved = await _persist();
    if (saved == null) return;
    _setActive(saved);
    ref.read(importControllerProvider.notifier).start(saved);
    navigator.pop();
  }

  Future<void> _refresh() async {
    final navigator = Navigator.of(context);
    final saved = await _persist();
    if (saved == null) return;
    ref.read(importControllerProvider.notifier).start(saved);
    navigator.pop();
  }

  Future<void> _activate() async {
    final navigator = Navigator.of(context);
    final saved = await _persist();
    if (saved == null) return;
    _setActive(saved);
    navigator.pop();
  }

  Future<void> _delete() async {
    final source = widget.source;
    if (source == null) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final choice = await showAeroMenu(
      context,
      title: l10n.playlistDeleteConfirm(source.name),
      options: [l10n.confirmKeep, l10n.confirmDelete],
    );
    if (choice != 1) return;
    await ref.read(playlistRepositoryProvider).delete(source.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final source = widget.source;
    String shown(String value) =>
        value.isEmpty ? l10n.playlistEmptyField : value;
    final language = ref.watch(
      settingsProvider.select((settings) => settings.languageCode),
    );

    final fields = <_Field>[
      (
        label: l10n.playlistName,
        value: shown(_name),
        edit: () =>
            _editText(l10n.playlistName, _name, (value) => _name = value),
      ),
      (
        label: l10n.playlistType,
        value: _kind == SourceKind.m3u ? 'M3U' : 'Xtream Codes',
        edit: _chooseKind,
      ),
      if (_kind == SourceKind.m3u) ...[
        (
          label: l10n.playlistUrl,
          value: shown(_url),
          edit: () =>
              _editText(l10n.playlistUrl, _url, (value) => _url = value),
        ),
        (
          label: l10n.playlistEpgUrl,
          value: shown(_epgUrl),
          edit: () => _editText(
            l10n.playlistEpgUrl,
            _epgUrl,
            (value) => _epgUrl = value,
          ),
        ),
      ] else ...[
        (
          label: l10n.playlistServer,
          value: shown(_server),
          edit: () => _editText(
            l10n.playlistServer,
            _server,
            (value) => _server = value,
          ),
        ),
        (
          label: l10n.playlistUsername,
          value: shown(_username),
          edit: () => _editText(
            l10n.playlistUsername,
            _username,
            (value) => _username = value,
          ),
        ),
        (
          label: l10n.playlistPassword,
          value: _password.isEmpty
              ? l10n.playlistEmptyField
              : '•' * _password.length,
          edit: () => _editText(
            l10n.playlistPassword,
            _password,
            (value) => _password = value,
            obscure: true,
          ),
        ),
      ],
      (
        label: l10n.playlistCountry,
        value: _country == null
            ? l10n.playlistCountryNone
            : countryName(_country!, language) ?? _country!,
        edit: _chooseCountry,
      ),
    ];

    return FocusGuard(
      fallback: () => _saveNode,
      child: AeroCanvas(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 160, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                source == null ? l10n.playlistNew : l10n.playlistEdit,
                style: AeroText.title,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: fields.length * 64.0 + 40,
                child: GlassPanel(
                  padding: const EdgeInsets.all(12),
                  child: DpadCollection.vertical(
                    autofocus: true,
                    itemCount: fields.length,
                    itemExtent: 56,
                    padding: const EdgeInsets.all(4),
                    onSelect: (index) => fields[index].edit(),
                    itemBuilder: (context, index, focused) => SettingRow(
                      label: fields[index].label,
                      value: fields[index].value,
                      focused: focused,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AeroText.body),
              ],
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AeroButton(
                    label: l10n.actionBack,
                    onSelect: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 16),
                  // Les libellés varient selon la langue : un bouton sorti de
                  // sa rangée s'afficherait encore, mais ne recevrait aucun clic.
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        if (source != null) ...[
                          AeroButton(
                            label: l10n.playlistDelete,
                            onSelect: _delete,
                          ),
                          AeroButton(
                            label: l10n.playlistRefresh,
                            onSelect: _refresh,
                          ),
                          AeroButton(
                            label: l10n.playlistActivate,
                            onSelect: _activate,
                          ),
                        ],
                        AeroButton(
                          label: l10n.playlistSave,
                          focusNode: _saveNode,
                          onSelect: _save,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
