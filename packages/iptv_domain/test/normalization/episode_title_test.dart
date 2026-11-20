import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  test('garde ce qui suit le marqueur d épisode', () {
    expect(
      episodeTitleOf('EN - Dexter (2006) - S01E02 - Crocodile', 'Dexter'),
      'Crocodile',
    );
    expect(episodeTitleOf('Lost 1x05 : White Rabbit', 'Lost'), 'White Rabbit');
  });

  test('écarte le titre de la série et les titres génériques', () {
    expect(
      episodeTitleOf('EN - Dexter (2006) - S01E01 - Dexter', 'Dexter'),
      isNull,
    );
    expect(episodeTitleOf('Dexter - S01E03', 'Dexter'), isNull);
    expect(episodeTitleOf('Épisode 4', 'Dexter'), isNull);
    expect(episodeTitleOf('Dexter', 'dexter'), isNull);
    expect(episodeTitleOf('  ', 'Dexter'), isNull);
    expect(episodeTitleOf(null, 'Dexter'), isNull);
  });

  test('laisse intact un titre déjà propre', () {
    expect(episodeTitleOf('Popping Cherry', 'Dexter'), 'Popping Cherry');
  });
}
