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
      // Une seule validation par appui : maintenu, OK se répète sur Android,
      // et chaque répétition validerait l'écran ou le menu qui vient de
      // s'ouvrir.
      SingleActivator(LogicalKeyboardKey.select, includeRepeats: false):
          ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
          ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.numpadEnter, includeRepeats: false):
          ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonA, includeRepeats: false):
          ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.escape): BackIntent(),
      SingleActivator(LogicalKeyboardKey.goBack): BackIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonB): BackIntent(),
    };
