import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:aero_iptv/l10n/version_names.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  String name(String label, {String? variant}) =>
      versionName(label, l10n, 'fr', variant: variant);

  test('nomme la langue de l audio', () {
    expect(name('FR'), 'Français');
    expect(name('EN'), 'Anglais');
    expect(name('GR'), 'Grec');
    expect(name('AR'), 'Arabe');
    expect(name('BG'), 'Bulgare');
    expect(name('SC'), 'Scandinave');
  });

  test('garde la qualité à côté de la langue', () {
    expect(name('4K-DE'), 'Allemand 4K');
    expect(name('4K-SC'), 'Scandinave 4K');
  });

  test('un libellé sans langue reste tel quel', () {
    expect(name('4K'), '4K');
    expect(name('NF'), 'NF');
  });

  test('précise le sous-titrage, le doublage et le bouquet', () {
    expect(name('DE SUB'), 'Allemand (sous-titré)');
    expect(name('IR DUB'), 'Persan (doublé)');
    expect(name('FR', variant: 'Netflix'), 'Français (Netflix)');
  });

  test('ne confond pas un titre brut avec un libellé', () {
    expect(name('No Time To Die'), 'No Time To Die');
    expect(audioLanguageOf('No Time To Die'), isNull);
  });

  test('place la langue de l utilisateur en tête', () {
    expect(
      versionsByLanguage(const ['EN', '4K', 'FR', '4K-FR'], (v) => v, 'fr'),
      ['FR', '4K-FR', 'EN', '4K'],
    );
  });

  test('le bouquet ne sert qu à distinguer deux libellés identiques', () {
    Movie movie(String tag, String category) => Movie(
      id: 1,
      title: 'Lagon',
      rawTitle: '$tag - Lagon',
      contentKey: 'cle',
      locator: const DirectStream('http://s/1.mkv'),
      languageTag: tag,
      category: category,
    );

    expect(
      movieVersionNames(
        [movie('FR', 'Action'), movie('FR', 'Netflix'), movie('EN', 'Cinéma')],
        l10n,
        'fr',
      ),
      ['Français (Action)', 'Français (Netflix)', 'Anglais'],
    );
  });
}
