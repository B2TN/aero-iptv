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

  test('relève le code d une erreur de la base', () {
    final failure = importFailureOf(
      SqliteException(extendedResultCode: 6410, message: 'disk I/O error'),
    );

    expect(failure, isA<StorageFailure>());
    expect((failure as StorageFailure).code, 6410);
    expect(failure.isFull, isFalse);
  });

  test('retrouve le code dans le texte d une erreur relayée', () {
    final failure = importFailureOf(
      const _Relayed('SqliteException(13): while executing, database is full'),
    );

    expect((failure as StorageFailure).code, 13);
    expect(failure.isFull, isTrue);
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
