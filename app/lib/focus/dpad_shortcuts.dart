import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Demande de retour à l'écran précédent.
class BackIntent extends Intent {
  const BackIntent();
}

/// Touches de retour : celle de la télécommande, Échap et B de la manette.
bool isBackKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.goBack ||
    key == LogicalKeyboardKey.escape ||
    key == LogicalKeyboardKey.gameButtonB;

/// Touches qui valident, sur une télécommande comme sur un clavier.
bool isConfirmKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.numpadEnter ||
    key == LogicalKeyboardKey.gameButtonA;

/// Touches de la télécommande et du clavier, valables dans toute l'application.
///
/// Sur Android, la touche Retour n'y figure pas : Android en fait lui-même un
/// retour système, que reçoivent le navigateur et les `PopScope`. La traiter
/// aussi ici ferait deux retours pour un appui : la fiche fermée, puis le
/// focus rendu à la barre ; le HUD masqué, puis la lecture quittée.
final Map<ShortcutActivator, Intent> dpadShortcuts =
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
      SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false):
          BackIntent(),
      if (!Platform.isAndroid)
        const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false):
            const BackIntent(),
      SingleActivator(LogicalKeyboardKey.gameButtonB, includeRepeats: false):
          BackIntent(),
    };
