import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../focus/dpad_collection.dart';
import '../tokens/aero_tokens.dart';

/// Touche spéciale du clavier virtuel.
enum KeyboardAction { space, delete, nextLayout }

/// Jeu de touches.
enum KeyboardLayout {
  lower('abcdefghijklmnopqrstuvwxyz0123456789'),
  upper('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'),
  symbols(':/.-_?=&@%#+~!\$*()[]{}|;,\'"<>^`\\ '),
  arabic('ابتثجحخدذرزسشصضطظعغفقكلمنهويءأإآة0123456789');

  const KeyboardLayout(this.characters);

  final String characters;

  List<String> get keys => characters.trim().split('');
}

/// Clavier virtuel pilotable au D-pad.
class VirtualKeyboard extends StatefulWidget {
  const VirtualKeyboard({
    required this.onCharacter,
    required this.onAction,
    this.layouts = const [KeyboardLayout.lower],
    this.columns = 7,
    this.keySize = 44,
    this.autofocus = false,
    this.focusNode,
    this.memoryKey,
    super.key,
  });

  final ValueChanged<String> onCharacter;
  final ValueChanged<KeyboardAction> onAction;

  /// Jeux de touches accessibles. La touche de bascule n'existe que s'il y en a
  /// plusieurs.
  final List<KeyboardLayout> layouts;
  final int columns;
  final double keySize;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? memoryKey;

  @override
  State<VirtualKeyboard> createState() => _VirtualKeyboardState();
}

class _VirtualKeyboardState extends State<VirtualKeyboard> {
  int _layout = 0;

  List<Object> get _keys => [
    ...widget.layouts[_layout].keys,
    KeyboardAction.space,
    KeyboardAction.delete,
    if (widget.layouts.length > 1) KeyboardAction.nextLayout,
  ];

  void _press(Object key) {
    switch (key) {
      case final String character:
        widget.onCharacter(character);
      case KeyboardAction.nextLayout:
        setState(() => _layout = (_layout + 1) % widget.layouts.length);
      case final KeyboardAction action:
        widget.onAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keys;
    final rows = (keys.length / widget.columns).ceil();
    return SizedBox(
      height: rows * (widget.keySize + 6) + 8,
      child: DpadCollection.grid(
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        memoryKey: widget.memoryKey,
        itemCount: keys.length,
        itemExtent: widget.keySize,
        columns: widget.columns,
        spacing: 6,
        padding: const EdgeInsets.all(4),
        focusScale: 1.0,
        onSelect: (index) => _press(keys[index]),
        itemBuilder: (context, index, focused) =>
            _KeyCap(value: keys[index], focused: focused),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.value, required this.focused});

  final Object value;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final color = focused ? AeroColors.leaf : AeroColors.foam;
    final Widget label = switch (value) {
      final String character => Text(
        character,
        style: AeroText.heading.copyWith(color: color),
      ),
      KeyboardAction.space => Icon(Icons.space_bar, color: color, size: 22),
      KeyboardAction.delete => Icon(
        Icons.backspace_outlined,
        color: color,
        size: 20,
      ),
      _ => Icon(Icons.keyboard_alt_outlined, color: color, size: 22),
    };
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0x33E8FBFF),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Center(child: label),
    );
  }
}
