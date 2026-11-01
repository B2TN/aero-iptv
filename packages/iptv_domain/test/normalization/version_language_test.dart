import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Libellés relevés sur un vrai catalogue de 46 413 séries.
void main() {
  group('audioLanguageOf', () {
    test('lit la langue dans le libellé du fournisseur', () {
      expect(audioLanguageOf('FR'), 'fr');
      expect(audioLanguageOf('4K-DE'), 'de');
      expect(audioLanguageOf('DE SUB'), 'de');
      expect(audioLanguageOf('SC-4K'), 'scn');
      expect(audioLanguageOf('QFR'), 'qc');
      expect(audioLanguageOf('LATINO'), 'lat');
    });

    test('ne devine rien sans langue dans le libellé', () {
      expect(audioLanguageOf(null), isNull);
      expect(audioLanguageOf('4K'), isNull);
      expect(audioLanguageOf('NF'), isNull);
      expect(audioLanguageOf('MULTI'), isNull);
      expect(audioLanguageOf('No Time To Die'), isNull);
    });
  });

  group('versionsByLanguage', () {
    List<String?> sorted(List<String?> labels, String language) =>
        versionsByLanguage(labels, (label) => label, language);

    test('la langue exacte passe avant ses déclinaisons', () {
      expect(sorted(['4K-DE', 'DE SUB', 'DE'], 'de'), [
        'DE',
        '4K-DE',
        'DE SUB',
      ]);
    });

    test('une variante régionale passe avant l anglais', () {
      expect(sorted(['EN', 'QFR'], 'fr'), ['QFR', 'EN']);
      expect(sorted(['EN', 'LAT', 'ES'], 'es'), ['ES', 'LAT', 'EN']);
    });

    test('sans la langue voulue, l anglais passe en premier', () {
      expect(sorted(['DE', 'AR', 'EN'], 'fr').first, 'EN');
    });

    test('une version sans langue passe après l anglais', () {
      expect(sorted(['DE', null, 'EN', '4K'], 'fr'), ['EN', null, '4K', 'DE']);
    });

    test('garde l ordre du catalogue à rang égal', () {
      expect(sorted(['DE', 'AR', 'PL'], 'fr'), ['DE', 'AR', 'PL']);
    });
  });

  test('liste les libellés d une langue', () {
    expect(languageTags('fr'), containsAll(['FR', 'VF', 'VFF']));
    expect(languageTags('ar'), containsAll(['AR', 'ARA']));
    expect(languageTags('xx'), isEmpty);
  });
}
