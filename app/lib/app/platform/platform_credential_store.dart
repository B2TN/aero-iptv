import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:path/path.dart' as p;

/// Coffre de la plateforme.
CredentialStore createCredentialStore(Directory directory) => Platform.isWindows
    ? WindowsCredentialStore(directory)
    : const AndroidCredentialStore();

/// Coffre Android : le chiffrement repose sur le Keystore du système, via le
/// canal natif écrit à l'étape de build.
final class AndroidCredentialStore implements CredentialStore {
  const AndroidCredentialStore();

  static const MethodChannel _channel = MethodChannel('aero_iptv/secure_store');

  String _key(int sourceId) => 'source_$sourceId';

  /// Une erreur du Keystore devient une erreur métier : l'interface sait alors
  /// l'afficher, au lieu de laisser une exception non gérée.
  Future<T> _guarded<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException {
      throw const StorageFailure('Coffre Android indisponible.');
    }
  }

  @override
  Future<PlaylistCredentials?> read(int sourceId) => _guarded(() async {
    final value = await _channel.invokeMethod<String>('read', _key(sourceId));
    return value == null ? null : decodeCredentials(utf8.encode(value));
  });

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) => _guarded(
    () => _channel.invokeMethod<void>('write', {
      'key': _key(sourceId),
      'value': jsonEncode(credentials.toMap()),
    }),
  );

  @override
  Future<void> delete(int sourceId) =>
      _guarded(() => _channel.invokeMethod<void>('delete', _key(sourceId)));
}

/// Coffre Windows : DPAPI chiffre les données avec la session de l'utilisateur.
///
/// Cette API remplace `flutter_secure_storage`, dont le plugin Windows exige le
/// composant ATL de Visual Studio pour compiler.
final class WindowsCredentialStore implements CredentialStore {
  const WindowsCredentialStore(this._directory);

  final Directory _directory;

  File _file(int sourceId) =>
      File(p.join(_directory.path, 'source_$sourceId.bin'));

  @override
  Future<PlaylistCredentials?> read(int sourceId) async {
    final file = _file(sourceId);
    if (!file.existsSync()) return null;
    return decodeCredentials(unprotectData(await file.readAsBytes()));
  }

  @override
  Future<void> write(int sourceId, PlaylistCredentials credentials) async {
    await _directory.create(recursive: true);
    await _file(sourceId).writeAsBytes(
      protectData(utf8.encode(jsonEncode(credentials.toMap()))),
      flush: true,
    );
  }

  @override
  Future<void> delete(int sourceId) async {
    final file = _file(sourceId);
    if (file.existsSync()) await file.delete();
  }
}

PlaylistCredentials decodeCredentials(List<int> bytes) {
  final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  return PlaylistCredentials.fromMap(map.cast<String, String>());
}

final class _DataBlob extends Struct {
  @Uint32()
  external int size;

  external Pointer<Uint8> data;
}

typedef _CryptNative =
    Int32 Function(
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_DataBlob>,
    );
typedef _Crypt =
    int Function(
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_DataBlob>,
    );

/// Interdit toute fenêtre système pendant le chiffrement.
const int _cryptProtectUiForbidden = 0x1;

final DynamicLibrary _crypt32 = DynamicLibrary.open('crypt32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final _Crypt _protect = _crypt32.lookupFunction<_CryptNative, _Crypt>(
  'CryptProtectData',
);
final _Crypt _unprotect = _crypt32.lookupFunction<_CryptNative, _Crypt>(
  'CryptUnprotectData',
);
final Pointer<Void> Function(Pointer<Void>) _localFree = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)
    >('LocalFree');

/// Chiffre [data] pour la session Windows courante.
Uint8List protectData(List<int> data) => _transform(data, _protect);

/// Déchiffre des données produites par [protectData].
Uint8List unprotectData(List<int> data) => _transform(data, _unprotect);

Uint8List _transform(List<int> input, _Crypt operation) {
  final source = calloc<Uint8>(input.isEmpty ? 1 : input.length);
  final inputBlob = calloc<_DataBlob>();
  final outputBlob = calloc<_DataBlob>();
  try {
    source.asTypedList(input.length).setAll(0, input);
    inputBlob.ref
      ..size = input.length
      ..data = source;
    final succeeded = operation(
      inputBlob,
      nullptr,
      nullptr,
      nullptr,
      nullptr,
      _cryptProtectUiForbidden,
      outputBlob,
    );
    if (succeeded == 0) {
      throw const StorageFailure('Le coffre Windows a refusé l’opération.');
    }
    final output = outputBlob.ref;
    final result = Uint8List.fromList(output.data.asTypedList(output.size));
    _localFree(output.data.cast());
    return result;
  } finally {
    calloc
      ..free(source)
      ..free(inputBlob)
      ..free(outputBlob);
  }
}
