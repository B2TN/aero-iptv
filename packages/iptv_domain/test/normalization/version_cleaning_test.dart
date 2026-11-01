import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

/// Titres relevés sur un vrai catalogue de 46 413 séries.
void main() {
  const cleaner = TitleCleaner();
  ParsedTitle parse(String raw) => cleaner.parse(raw, ContentKind.series);

  group('Regroupement des versions', () {
    test('tous les préfixes mènent à la même clé', () {
      for (final raw in [
        'EN - Dexter: Resurrection (2025) (US)',
        'BG - Dexter: Resurrection (2025) (US)',
        'EX - Dexter: Resurrection (2025)',
        'SC - Dexter: Resurrection (2025) (US)',
        '4K-SC - Dexter: Resurrection (2025) (US)',
        '4K - Dexter: Resurrection (2025) (US)',
        'GR - Dexter: Resurrection (2025) (US)',
        'AR - Dexter: Resurrection (2025) (US)',
        'NL - DEXTER RESURRECTION (2025)',
        '[SE] Dexter: Resurrection',
        'IR - Dexter: Resurrection دکستر رستاخیز (DUB) (2025)',
      ]) {
        expect(
          GroupingKey.of(parse(raw).title),
          'dexterresurrection',
          reason: raw,
        );
      }
    });

    test('le préfixe nomme la version, pas le pays d origine', () {
      expect(parse('FR - Dexter: Resurrection (2025) (US)').versionLabel, 'FR');
      expect(parse('GR - Dexter: Resurrection (2025) (US)').versionLabel, 'GR');
      expect(parse('4K - Dexter: Resurrection (2025) (US)').versionLabel, '4K');
      expect(
        parse('4K-SC - Dexter: Resurrection (2025) (US)').versionLabel,
        '4K-SC',
      );
      expect(parse('FR - Dexter (2006) (US)').language, 'FR');
    });

    test('une mention de sous-titrage quitte le titre', () {
      final parsed = parse('DE - Mobile Suit Zeta Gundam (1985) (Ger Sub)');
      expect(parsed.title, 'Mobile Suit Zeta Gundam');
      expect(parsed.versionLabel, 'DE SUB');
      expect(parsed.year, 1985);
    });

    test('un sigle de titre n est pas pris pour un préfixe', () {
      expect(parse('CSI - Miami (2002)').title, 'CSI - Miami');
      expect(parse('FBI - Most Wanted (2020)').title, 'FBI - Most Wanted');
    });

    test('sans préfixe, le pays d origine indique encore la langue', () {
      expect(parse('Dexter (2006) (US)').language, 'EN');
      expect(parse('Dexter (2006) (US)').versionLabel, isNull);
    });
  });

  group('Préfixes de bouquet', () {
    test('ne restent pas dans le titre', () {
      for (final (raw, title, label) in const [
        ('DE-BLURAY-DV - Attack on Titan (2013) (JP)', 'Attack on Titan', 'DE'),
        (
          'DE- [4K-DV-HDR] - 4 Blocks Zero (2026) (DE)',
          '4 Blocks Zero',
          '4K-DE',
        ),
        ('DE-4K-BLURAY-DV - Ahsoka (2023) (US)', 'Ahsoka', '4K-DE'),
        ('IT-[4K] - American Gods (2017) (US)', 'American Gods', '4K-IT'),
        ('SC-4K-HDR - East of Eden (2026) (US)', 'East of Eden', '4K-SC'),
        ('SC-4K- Neagley (2026) (US)', 'Neagley', '4K-SC'),
      ]) {
        final parsed = parse(raw);
        expect(parsed.title, title, reason: raw);
        expect(parsed.versionLabel, label, reason: raw);
      }
    });

    test('un titre à tiret n est pas touché', () {
      expect(parse('EN - MR-9: Do Or Die (2023)').title, 'MR-9: Do Or Die');
      expect(parse('DE - JU-ON: Origins (2020)').title, 'JU-ON: Origins');
    });
  });

  group('VersionGrouper', () {
    const tmdbPoster = 'https://image.tmdb.org/t/p/original/affiche.jpg';

    test('relie un titre traduit par son affiche', () {
      final merged = VersionGrouper.merge(const [
        VersionCandidate(
          groupingKey: 'dexterresurrection',
          posterUrl: tmdbPoster,
          year: 2025,
        ),
        VersionCandidate(
          groupingKey: 'dexterresurrection',
          posterUrl: tmdbPoster,
          year: 2025,
        ),
        VersionCandidate(
          groupingKey: 'dexterzmartwychstanie',
          posterUrl: tmdbPoster,
        ),
      ]);
      expect(merged, {'dexterzmartwychstanie': 'dexterresurrection'});
    });

    test('relie un titre traduit par son identifiant TMDb', () {
      final merged = VersionGrouper.merge(const [
        VersionCandidate(groupingKey: 'dexterresurrection', tmdbId: '259909'),
        VersionCandidate(groupingKey: 'dexterresurrection', tmdbId: '259909'),
        VersionCandidate(groupingKey: 'dexterwiedererwachen', tmdbId: '259909'),
      ]);
      expect(merged, {'dexterwiedererwachen': 'dexterresurrection'});
    });

    test('relie les traductions d une franchise de la même année', () {
      final merged = VersionGrouper.merge(const [
        VersionCandidate(
          groupingKey: 'dexterresurrection',
          title: 'Dexter: Resurrection',
          label: 'EN',
          year: 2025,
        ),
        VersionCandidate(
          groupingKey: 'dexterresurrection',
          title: 'Dexter: Resurrection',
          label: 'FR',
          year: 2025,
        ),
        VersionCandidate(
          groupingKey: 'dexterwiedererwachen',
          title: 'Dexter: Wiedererwachen',
          label: 'DE',
          year: 2025,
        ),
        VersionCandidate(
          groupingKey: 'dexterzmartwychstanie',
          title: 'Dexter: Zmartwychstanie',
          label: 'PL',
          year: 2025,
        ),
      ]);
      expect(merged, {
        'dexterwiedererwachen': 'dexterresurrection',
        'dexterzmartwychstanie': 'dexterresurrection',
      });
    });

    test('une même langue prouve deux séries différentes', () {
      expect(
        VersionGrouper.merge(const [
          VersionCandidate(
            groupingKey: 'marvelspotlight',
            title: 'Marvel: Spotlight',
            label: 'EN',
            year: 2025,
          ),
          VersionCandidate(
            groupingKey: 'marvelzombies',
            title: 'Marvel: Zombies',
            label: 'EN',
            year: 2025,
          ),
        ]),
        isEmpty,
      );
    });

    test('une autre année n appartient pas au même titre', () {
      expect(
        VersionGrouper.merge(const [
          VersionCandidate(
            groupingKey: 'dexterresurrection',
            title: 'Dexter: Resurrection',
            label: 'EN',
            year: 2025,
          ),
          VersionCandidate(
            groupingKey: 'dexteroriginalsin',
            title: 'Dexter: Original Sin',
            label: 'FR',
            year: 2024,
          ),
        ]),
        isEmpty,
      );
    });

    test('ignore une affiche partagée par trop de titres', () {
      final entries = [
        for (var index = 0; index < 7; index++)
          VersionCandidate(groupingKey: 'titre$index', posterUrl: tmdbPoster),
      ];
      expect(VersionGrouper.merge(entries), isEmpty);
    });

    test('ne relie pas deux années éloignées', () {
      expect(
        VersionGrouper.merge(const [
          VersionCandidate(groupingKey: 'a', posterUrl: tmdbPoster, year: 1990),
          VersionCandidate(groupingKey: 'b', posterUrl: tmdbPoster, year: 2020),
        ]),
        isEmpty,
      );
    });

    test('ne se fie pas aux images des autres hébergeurs', () {
      const url = 'http://103.176.90.154/images/cover.jpg';
      expect(
        VersionGrouper.merge(const [
          VersionCandidate(groupingKey: 'a', posterUrl: url),
          VersionCandidate(groupingKey: 'b', posterUrl: url),
        ]),
        isEmpty,
      );
    });

    test('ignore un identifiant TMDb vide', () {
      expect(
        VersionGrouper.merge(const [
          VersionCandidate(groupingKey: 'a', tmdbId: '0'),
          VersionCandidate(groupingKey: 'b', tmdbId: '0'),
        ]),
        isEmpty,
      );
    });
  });
}
