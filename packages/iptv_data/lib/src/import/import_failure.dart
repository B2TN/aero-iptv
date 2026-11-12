import 'package:drift/isolate.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:sqlite3/common.dart';

/// Code d'une erreur SQLite, relevé dans son texte quand l'objet lui-même n'a
/// pas survécu au passage entre isolates.
final RegExp _sqliteCode = RegExp(r'SqliteException\((\d+)\)');

/// Range parmi les échecs une erreur que l'import n'attendait pas.
///
/// Rien n'est gardé de son texte : il peut contenir l'adresse du serveur, et
/// donc le mot de passe de l'abonné. Le code SQLite et le nom du type suffisent
/// à retrouver la cause, et peuvent s'afficher.
Failure importFailureOf(Object error) {
  if (error is Failure) return error;
  final cause = error is DriftRemoteException ? error.remoteCause : error;
  final code = cause is SqliteException
      ? cause.extendedResultCode
      : int.tryParse(_sqliteCode.firstMatch('$cause')?.group(1) ?? '');
  if (code != null) return StorageFailure('Écriture refusée.', code: code);
  return UnexpectedFailure('Import interrompu.', kind: '${cause.runtimeType}');
}
