import 'package:iptv_data/src/import/import_failure.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:sqlite3/common.dart';
import 'package:test/test.dart';

/// Erreur arrivée d'un autre isolate sous forme de texte seulement.
final class _Relayed implements Exception {
  const _Relayed(this.text);

  final String text;

  @override
  String toString() => text;
}

void main() {
  test('garde un échec déjà rangé', () {
    const failure = NetworkFailure('x');

    expect(importFailureOf(failure), same(failure));
  });

  test('relève le code et le message d une erreur de la base', () {
    final failure = importFailureOf(
      SqliteException(
        extendedResultCode: 1,
        message: 'no such column: poster_url',
        causingStatement: 'INSERT INTO search_index SELECT ?',
        parametersToStatement: const ['http://hote/get.php?password=p'],
      ),
    );

    expect(failure, isA<StorageFailure>());
    final storage = failure as StorageFailure;
    expect(storage.code, 1);
    expect(storage.isFull, isFalse);
    expect(storage.detail, startsWith('no such column: poster_url, SQLite 3.'));
    expect(storage.detail, isNot(contains('INSERT')));
    expect(storage.detail, isNot(contains('password')));
  });

  test('retrouve le code et le message d une erreur relayée', () {
    final failure = importFailureOf(
      const _Relayed(
        'SqliteException(13): while executing, database or disk is full\n'
        '  Causing statement: UPDATE movies SET title = ?\n'
        '  Parameters: secret',
      ),
    );

    final storage = failure as StorageFailure;
    expect(storage.code, 13);
    expect(storage.isFull, isTrue);
    expect(storage.detail, startsWith('database or disk is full, SQLite'));
    expect(storage.detail, isNot(contains('secret')));
  });

  test('écarte un message qui ressemble à une adresse', () {
    final failure = importFailureOf(
      SqliteException(extendedResultCode: 1, message: 'http://hote/x failed'),
    );

    expect((failure as StorageFailure).detail, isNot(contains('hote')));
  });

  test('reconnaît un stockage plein à son code étendu', () {
    // 13 avec une précision dans les bits de poids fort.
    expect(const StorageFailure('x', code: 13 | 1 << 8).isFull, isTrue);
    expect(const StorageFailure('x').isFull, isFalse);
  });

  test('ne garde que le nom d une erreur inattendue', () {
    final failure = importFailureOf(
      const FormatException('http://hote/get.php?username=u&password=p'),
    );

    expect(failure, isA<UnexpectedFailure>());
    expect((failure as UnexpectedFailure).kind, 'FormatException');
    expect(failure.toString(), isNot(contains('password')));
  });
}
