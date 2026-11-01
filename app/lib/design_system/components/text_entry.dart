import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../glass/glass_panel.dart';
import '../tokens/aero_tokens.dart';
import 'aero_button.dart';
import 'aero_menu.dart';
import 'virtual_keyboard.dart';

const double _entryWidth = 720;

/// Bouton supplémentaire, à côté de « Afficher ».
typedef TextEntryAction = ({String label, VoidCallback onSelect});

/// Saisie de texte au clavier virtuel.
///
/// Un clavier physique fonctionne aussi, y compris le collage d'une adresse sur
/// PC. Retourne le texte validé, ou `null` si la saisie est annulée.
Future<String?> showTextEntry(
  BuildContext context, {
  required String title,
  String initial = '',
  bool obscure = false,
  TextEntryAction? action,
}) => showAeroOverlay<String>(
  context,
  label: title,
  builder: (context) => _TextEntry(
    title: title,
    initial: initial,
    obscure: obscure,
    action: action,
  ),
);

class _TextEntry extends StatefulWidget {
  const _TextEntry({
    required this.title,
    required this.initial,
    required this.obscure,
    required this.action,
  });

  final String title;
  final String initial;
  final bool obscure;
  final TextEntryAction? action;

  @override
  State<_TextEntry> createState() => _TextEntryState();
}

class _TextEntryState extends State<_TextEntry> {
  late String _text = widget.initial;
  bool _revealed = false;

  void _append(String value) => setState(() => _text += value);

  void _delete() {
    if (_text.isEmpty) return;
    setState(
      () => _text = String.fromCharCodes(_text.runes.toList()..removeLast()),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text;
    if (value != null && mounted) _append(value.trim());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _delete();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey != LogicalKeyboardKey.keyV) {
        return KeyEventResult.ignored;
      }
      _paste();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character == null || character.runes.first < 0x20) {
      return KeyEventResult.ignored;
    }
    _append(character);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final action = widget.action;
    final shown = widget.obscure && !_revealed ? '•' * _text.length : _text;
    return Center(
      child: SizedBox(
        width: _entryWidth,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKeyEvent,
          child: GlassPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.title, style: AeroText.heading),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AeroColors.veil,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '$shown|',
                      style: AeroText.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                VirtualKeyboard(
                  autofocus: true,
                  columns: 13,
                  keySize: 44,
                  layouts: const [
                    KeyboardLayout.lower,
                    KeyboardLayout.upper,
                    KeyboardLayout.symbols,
                  ],
                  onCharacter: _append,
                  onAction: (action) => action == KeyboardAction.delete
                      ? _delete()
                      : _append(' '),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Les libellés varient selon la langue : ces boutons
                    // rétrécissent au lieu de pousser ceux de droite.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.obscure)
                              AeroButton(
                                label: _revealed
                                    ? l10n.entryHide
                                    : l10n.entryShow,
                                onSelect: () =>
                                    setState(() => _revealed = !_revealed),
                              ),
                            if (action != null) ...[
                              const SizedBox(width: 16),
                              AeroButton(
                                label: action.label,
                                onSelect: action.onSelect,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    AeroButton(
                      label: l10n.entryCancel,
                      onSelect: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    AeroButton(
                      label: l10n.entryConfirm,
                      onSelect: () => Navigator.of(context).pop(_text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
