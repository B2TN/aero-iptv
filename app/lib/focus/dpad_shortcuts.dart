import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Demande de retour à l'écran précédent.
class BackIntent extends Intent {
  const BackIntent();
}

/// Touches qui valident, sur une télécommande comme sur un clavier.
bool isConfirmKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.gameButtonA;

/// Touches de la télécommande et du clavier, valables dans toute l'application.
const Map<ShortcutActivator, Intent> dpadShortcuts =
    <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(
        TraversalDirection.up,
      ),
      SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(
        TraversalDirection.down,
      ),
      SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(
        TraversalDirection.left,
      ),
      SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(
        TraversalDirection.right,
      ),
      SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.escape): BackIntent(),
      SingleActivator(LogicalKeyboardKey.goBack): BackIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonB): BackIntent(),
    };
