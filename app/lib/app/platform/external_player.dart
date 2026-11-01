import 'dart:io';

import 'package:flutter/services.dart';

/// Lecteurs recherchés sous Windows, du plus au moins courant.
const List<String> _windowsPlayers = [
  r'VideoLAN\VLC\vlc.exe',
  r'mpv\mpv.exe',
  r'MPC-HC\mpc-hc64.exe',
];

/// Ouvre un flux dans un autre lecteur installé sur l'appareil.
abstract final class ExternalPlayer {
  static const MethodChannel _channel = MethodChannel(
    'aero_iptv/external_player',
  );

  /// Retourne `false` si aucun lecteur n'a pu être lancé.
  static Future<bool> open(String url, {required String title}) =>
      Platform.isWindows ? _openOnWindows(url) : _openOnAndroid(url, title);

  static Future<bool> _openOnAndroid(String url, String title) async {
    try {
      final opened = await _channel.invokeMethod<bool>('open', {
        'url': url,
        'title': title,
      });
      return opened ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> _openOnWindows(String url) async {
    final roots = [
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
      Platform.environment['LOCALAPPDATA'],
    ].nonNulls;
    final installed = [
      for (final root in roots)
        for (final player in _windowsPlayers) '$root\\$player',
    ].where((path) => File(path).existsSync());

    for (final program in [...installed, 'vlc', 'mpv']) {
      try {
        await Process.start(program, [url], mode: ProcessStartMode.detached);
        return true;
      } on ProcessException {
        continue;
      }
    }
    return false;
  }
}
