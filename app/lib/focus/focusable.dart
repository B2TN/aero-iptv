import 'package:flutter/widgets.dart';

import 'focus_frame.dart';

/// Élément sélectionnable isolé : bouton, onglet, zone du héros.
///
/// Il réagit à la télécommande, au clavier, à la souris et au tactile. Les
/// listes utilisent `DpadCollection`, plus économe.
class Focusable extends StatefulWidget {
  const Focusable({
    required this.builder,
    this.onSelect,
    this.focusNode,
    this.autofocus = false,
    this.scale = 1.05,
    this.halo = HaloShape.card,
    this.onFocusChange,
    super.key,
  });

  /// Construit l'élément selon qu'il a le focus ou non.
  final Widget Function(BuildContext context, bool focused) builder;

  /// `null` rend l'élément inactif et inaccessible au D-pad.
  final VoidCallback? onSelect;
  final FocusNode? focusNode;

  /// Prend le focus dès l'apparition, même si un autre élément l'a déjà.
  final bool autofocus;
  final double scale;
  final HaloShape halo;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<Focusable> {
  FocusNode? _ownNode;
  bool _focused = false;

  FocusNode get _node =>
      widget.focusNode ?? (_ownNode ??= FocusNode(debugLabel: 'Focusable'));

  @override
  void initState() {
    super.initState();
    if (!widget.autofocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) {
        _node.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
  }

  @override
  Widget build(BuildContext context) {
    final onSelect = widget.onSelect;
    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onSelect?.call();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _node,
        canRequestFocus: onSelect != null,
        onFocusChange: _onFocusChange,
        child: MouseRegion(
          cursor: onSelect != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          // Un vrai mouvement : `onEnter` se déclencherait aussi quand l'élément
          // apparaît sous une souris immobile, et volerait le focus.
          onHover: (_) {
            if (onSelect != null && !_node.hasFocus) _node.requestFocus();
          },
          child: GestureDetector(
            onTap: onSelect,
            behavior: HitTestBehavior.opaque,
            child: FocusFrame(
              focused: _focused,
              scale: widget.scale,
              halo: widget.halo,
              child: widget.builder(context, _focused),
            ),
          ),
        ),
      ),
    );
  }
}
