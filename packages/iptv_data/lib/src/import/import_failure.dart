import 'package:drift/isolate.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:sqlite3/sqlite3.dart';

/// Erreur SQLite relevée dans son texte, quand l'objet lui-même n'a pas
/// survécu au passage entre isolates : son code, puis son message. Les lignes
/// suivantes, qui citent la requête et ses valeurs, sont laissées de côté.
final RegExp _sqliteError = RegExp(
  r'SqliteException\((\d+)\): (?:while [^,\n]*, )?([^\n]*)',
);

/// Longueur gardée du message de SQLite : de quoi nommer une table ou une
/// colonne, pas davantage.
const int _detailLength = 120;

/// Range parmi les échecs une erreur que l'import n'attendait pas.
///
/// Rien n'est gardé du texte d'une erreur quelconque : il peut contenir
/// l'adresse du serveur, et donc le mot de passe de l'abonné. D'une erreur
/// SQLite, seuls le code et le message de la base sont gardés : SQLite n'y cite
/// jamais les valeurs d'une requête.
Failure importFailureOf(Object error) {
  if (error is Failure) return error;
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  final match = cause is SqliteException
      ? null
      : _sqliteError.firstMatch('$cause');
  final code = cause is SqliteException
      ? cause.extendedResultCode
      : int.tryParse(match?.group(1) ?? '');
  if (code == null) {
    return UnexpectedFailure(
      'Import interrompu.',
      kind: '${cause.runtimeType}',
    );
  }
  final message = cause is SqliteException ? cause.message : match?.group(2);
  return StorageFailure(
    'Écriture refusée.',
    code: code,
    detail: _detail(message),
  );
}

String? _detail(String? message) {
  var text = message?.trim() ?? '';
  // Par précaution, rien qui ressemble à une adresse ou à un compte.
  if (text.contains('://') || text.contains('@')) text = '';
  if (text.length > _detailLength) {
    text = '${text.substring(0, _detailLength)}…';
  }
  final version = _libraryVersion();
  final parts = [
    if (text.isNotEmpty) text,
    if (version != null) 'SQLite $version',
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

String? _libraryVersion() {
  try {
    return sqlite3.version.libVersion;
  } on Object {
    return null;
  }
}
