import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('aero_iptv/screen');

/// Garde l'écran allumé, ou le rend à la veille du système.
typedef ScreenAwake = Future<void> Function({required bool enabled});

/// Empêche l'écran de veille pendant une tâche longue où personne ne touche à
/// la télécommande. Sur une TV, la veille mettrait l'application en
/// arrière-plan, où le système peut l'arrêter avant la fin.
///
/// Sans effet hors d'Android : un import y dure moins que le délai de veille.
Future<void> keepScreenAwake({required bool enabled}) async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod<void>('set', enabled);
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}
