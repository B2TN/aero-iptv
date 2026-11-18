import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../focus/dpad_shortcuts.dart';
import '../../focus/focus_frame.dart';
import '../tokens/aero_tokens.dart';

/// Champ de saisie au clavier physique, pour le PC : curseur, sélection et
/// collage comme partout ailleurs. Sur TV, le clavier virtuel le remplace.
///
/// Entrée valide la saisie ; les flèches haut et bas quittent le champ.
class KeyboardField extends StatefulWidget {
  const KeyboardField({
    required this.controller,
    this.onSubmitted,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  /// Texte affiché tant que le champ est vide.
  final String? hint;
  final bool obscure;
  final bool autofocus;

  @override
  State<KeyboardField> createState() => _KeyboardFieldState();
}

class _KeyboardFieldState extends State<KeyboardField> {
  final FocusNode _node = FocusNode(debugLabel: 'KeyboardField');
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocus);
    widget.controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(KeyboardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _node.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() => _focused = _node.hasFocus);

  /// L'indication disparaît dès le premier caractère.
  void _onText() => setState(() {});

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (isConfirmKey(key)) {
      widget.onSubmitted?.call(widget.controller.text);
      return KeyEventResult.handled;
    }
    // Un champ d'une ligne n'a ni haut ni bas : ces flèches en sortent.
    if (key == LogicalKeyboardKey.arrowDown) {
      _node.focusInDirection(TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _node.focusInDirection(TraversalDirection.up);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hint;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: FocusFrame(
        focused: _focused,
        scale: 1,
        halo: HaloShape.pill,
        child: GestureDetector(
          onTap: _node.requestFocus,
          child: MouseRegion(
            cursor: SystemMouseCursors.text,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AeroColors.veil,
                // Arrondi du halo de focus, qui l'entoure.
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Stack(
                  children: [
                    if (hint != null && widget.controller.text.isEmpty)
                      IgnorePointer(
                        child: Text(
                          hint,
                          style: AeroText.body.copyWith(color: AeroColors.mist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    EditableText(
                      controller: widget.controller,
                      focusNode: _node,
                      autofocus: widget.autofocus,
                      obscureText: widget.obscure,
                      style: AeroText.body.copyWith(shadows: const []),
                      cursorColor: AeroColors.leaf,
                      backgroundCursorColor: AeroColors.mist,
                      selectionColor: const Color(0x667FE3FF),
                      maxLines: 1,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
