import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'platform_credential_store.dart';

/// Clés d'API saisies par l'utilisateur, conservées dans le coffre du système.
abstract interface class ApiKeyStore {
  Future<String?> read(String name);

  /// [value] à `null` efface la clé.
  Future<void> write(String name, String? value);
}

/// Coffre utilisé tant qu'aucun coffre réel n'est branché, comme dans les tests.
final class MemorylessApiKeyStore implements ApiKeyStore {
  const MemorylessApiKeyStore();

  @override
  Future<String?> read(String name) async => null;

  @override
  Future<void> write(String name, String? value) async {}
}

ApiKeyStore createApiKeyStore(Directory directory) => Platform.isWindows
    ? _WindowsApiKeyStore(directory)
    : const _AndroidApiKeyStore();

final class _WindowsApiKeyStore implements ApiKeyStore {
  const _WindowsApiKeyStore(this._directory);

  final Directory _directory;

  File _file(String name) => File(p.join(_directory.path, 'key_$name.bin'));

  @override
  Future<String?> read(String name) async {
    final file = _file(name);
    if (!file.existsSync()) return null;
    return utf8.decode(unprotectData(await file.readAsBytes()));
  }

  @override
  Future<void> write(String name, String? value) async {
    final file = _file(name);
    if (value == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await _directory.create(recursive: true);
    await file.writeAsBytes(protectData(utf8.encode(value)), flush: true);
  }
}

final class _AndroidApiKeyStore implements ApiKeyStore {
  const _AndroidApiKeyStore();

  static const MethodChannel _channel = MethodChannel('aero_iptv/secure_store');

  String _key(String name) => 'api_key_$name';

  @override
  Future<String?> read(String name) async {
    try {
      return await _channel.invokeMethod<String>('read', _key(name));
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(String name, String? value) => value == null
      ? _channel.invokeMethod<void>('delete', _key(name))
      : _channel.invokeMethod<void>('write', {
          'key': _key(name),
          'value': value,
        });
}
