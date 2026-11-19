import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Fichiers joints aux releases, sous des noms qui ne changent pas d'une
/// version à l'autre.
const String androidUpdateAsset = 'aero-iptv-fire-tv-armeabi-v7a.apk';
const String windowsUpdateAsset = 'aero-iptv-windows-x64-setup.exe';

/// Installe une mise à jour téléchargée, à la manière de la plateforme.
abstract interface class UpdateInstaller {
  /// Fichier joint à télécharger ici ; `null` si la plateforme ne s'installe
  /// pas depuis l'application.
  String? get assetName;

  /// Vrai si l'application peut lancer l'installation. Android demande que
  /// l'utilisateur l'autorise une fois à installer des applications.
  Future<bool> canInstall();

  /// Ouvre le réglage qui accorde cette autorisation.
  Future<void> openInstallSettings();

  /// Lance l'installation de [file]. Sous Windows, l'application se ferme
  /// pour laisser l'installateur la remplacer, puis il la relance.
  Future<void> install(File file);
}

/// Installation par Android (paquet APK) ou par l'installateur Windows.
final class PlatformUpdateInstaller implements UpdateInstaller {
  const PlatformUpdateInstaller();

  static const MethodChannel _channel = MethodChannel('aero_iptv/updates');

  @override
  String? get assetName => Platform.isAndroid
      ? androidUpdateAsset
      : Platform.isWindows
      ? windowsUpdateAsset
      : null;

  @override
  Future<bool> canInstall() async {
    if (!Platform.isAndroid) return true;
    return await _channel.invokeMethod<bool>('canInstall') ?? false;
  }

  @override
  Future<void> openInstallSettings() async {
    if (Platform.isAndroid) await _channel.invokeMethod<void>('openSettings');
  }

  @override
  Future<void> install(File file) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('install', {'path': file.path});
      return;
    }
    if (Platform.isWindows) {
      // Installation par utilisateur, sans question : l'installateur ferme
      // l'application si elle tarde, la remplace, puis la relance.
      await Process.start(file.path, [
        '/SILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      exit(0);
    }
  }
}
