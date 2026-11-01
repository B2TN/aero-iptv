import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/iptv_player.dart';

const MethodChannel _channel = MethodChannel('aero_iptv/device');
const int _lowMemoryLimitMb = 1600;
const int _mebibyte = 1024 * 1024;

/// Capacités de l'appareil, qui fixent les plafonds de mémoire.
final class DeviceProfile {
  const DeviceProfile({required this.memoryTier, required this.isTv});

  final MemoryTier memoryTier;
  final bool isTv;

  /// Plafond du cache d'images décodées.
  int get imageCacheBytes => switch (memoryTier) {
    MemoryTier.low => 24 * _mebibyte,
    MemoryTier.standard => 48 * _mebibyte,
    MemoryTier.desktop => 128 * _mebibyte,
  };

  /// Détecte l'appareil. En cas de doute, le profil le plus prudent s'applique :
  /// une TV inconnue est traitée comme un stick de 1 Go.
  static Future<DeviceProfile> detect() async {
    if (!Platform.isAndroid) {
      return const DeviceProfile(memoryTier: MemoryTier.desktop, isTv: false);
    }
    try {
      final info = await _channel.invokeMapMethod<String, Object>('profile');
      final ramMb = info?['totalRamMb'] as int? ?? 0;
      return DeviceProfile(
        memoryTier: ramMb > _lowMemoryLimitMb
            ? MemoryTier.standard
            : MemoryTier.low,
        isTv: info?['isTv'] as bool? ?? true,
      );
    } on MissingPluginException {
      debugPrint('Canal aero_iptv/device absent : profil prudent appliqué.');
      return const DeviceProfile(memoryTier: MemoryTier.low, isTv: true);
    }
  }
}
