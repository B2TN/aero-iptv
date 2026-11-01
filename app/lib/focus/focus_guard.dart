import 'package:flutter/widgets.dart';

/// Empêche l'utilisateur de se retrouver sans focus.
///
/// Si l'élément actif disparaît, par exemple quand une liste se vide après une
/// synchronisation, le focus retombe sur un élément sûr. Sans télécommande
/// tactile, l'application serait sinon bloquée.
class FocusGuard extends StatefulWidget {
  const FocusGuard({required this.fallback, required this.child, super.key});

  /// Élément qui reçoit le focus en cas de perte.
  final FocusNode Function() fallback;
  final Widget child;

  @override
  State<FocusGuard> createState() => _FocusGuardState();
}

class _FocusGuardState extends State<FocusGuard> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_check);
    super.dispose();
  }

  bool get _focusIsLost {
    final primary = FocusManager.instance.primaryFocus;
    return primary == null || primary is FocusScopeNode;
  }

  void _check() {
    if (_scheduled || !mounted || !_focusIsLost) return;
    _scheduled = true;
    // Attend la fin de l'image : un écran qui s'ouvre pose alors son autofocus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_focusIsLost) return;
      if (ModalRoute.isCurrentOf(context) ?? true) {
        widget.fallback().requestFocus();
      }
    });
    // Sans cette demande, une interface immobile ne produirait aucune image et
    // le focus resterait perdu jusqu'à l'événement suivant.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
