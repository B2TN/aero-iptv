import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  const cleaner = TitleCleaner();

  group('chaînes', () {
    final cases = <String, (String, StreamQuality)>{
      'FR: TF1 FHD': ('TF1', StreamQuality.fhd),
      '|FR| TF1 HD': ('TF1', StreamQuality.hd),
      '[FR] TF1 (SD)': ('TF1', StreamQuality.sd),
      '★ FR ★ TF1 ᶠᴴᴰ': ('TF1', StreamQuality.fhd),
      '🇫🇷 TF1 ᴴᴰ': ('TF1', StreamQuality.hd),
      'VIP FR: Canal+ 4K': ('Canal+', StreamQuality.uhd),
      'UK: BBC One HD+': ('BBC One', StreamQuality.hd),
      'Canal+ Sport 360 FHD': ('Canal+ Sport 360', StreamQuality.fhd),
      'BeIN Sports 1 FHD (Backup)': ('BeIN Sports 1', StreamQuality.fhd),
      'tf1 hd': ('tf1', StreamQuality.hd),
      'FR: TF1 www.super-iptv.com': ('TF1', StreamQuality.unknown),
    };
    cases.forEach((raw, expected) {
      test(raw, () {
        final parsed = cleaner.parse(raw, ContentKind.live);
        expect(parsed.title, expected.$1);
        expect(parsed.quality, expected.$2);
      });
    });

    test('conserve les décalages horaires', () {
      expect(cleaner.parse('E4 +1', ContentKind.live).title, 'E4 +1');
    });

    test('conserve un nom réduit à une mention de qualité', () {
      expect(cleaner.parse('4K', ContentKind.live).title, '4K');
      expect(cleaner.parse('FR: HD1 FHD', ContentKind.live).title, 'HD1');
    });

    test('conserve une parenthèse qui fait partie du nom', () {
      expect(
        cleaner.parse('Fox (East) HD', ContentKind.live).title,
        'Fox (East)',
      );
    });

    test('garde le codec pour le menu de flux', () {
      final parsed = cleaner.parse('FR: TF1 FHD HEVC', ContentKind.live);
      expect(parsed.title, 'TF1');
      expect(parsed.variantLabel, 'FHD HEVC');
    });

    test('extrait le pays du préfixe', () {
      expect(cleaner.parse('UK: BBC One', ContentKind.live).countryCode, 'GB');
    });

    test('ne confond pas un mot du titre avec une étiquette', () {
      expect(cleaner.parse('Arte.tv', ContentKind.live).title, 'Arte.tv');
    });

    test('repère les lignes de séparation', () {
      expect(cleaner.isHeaderEntry('#### FRANCE ####'), isTrue);
      expect(cleaner.isHeaderEntry('===== SPORTS ====='), isTrue);
      expect(cleaner.isHeaderEntry('TF1 HD'), isFalse);
    });
  });

  group('films', () {
    test('extrait année, qualité et langue', () {
      final parsed = cleaner.parse(
        'EN: Inception (2010) [4K]',
        ContentKind.movie,
      );
      expect(parsed.title, 'Inception');
      expect(parsed.year, 2010);
      expect(parsed.quality, StreamQuality.uhd);
      expect(parsed.language, 'EN');
    });

    test('lit une année et des mentions sans crochets', () {
      final parsed = cleaner.parse(
        'Inception 2010 MULTI 1080p',
        ContentKind.movie,
      );
      expect(parsed.title, 'Inception');
      expect(parsed.year, 2010);
      expect(parsed.language, 'MULTI');
      expect(parsed.quality, StreamQuality.fhd);
    });

    test('garde un titre composé d une année', () {
      expect(cleaner.parse('1917', ContentKind.movie).title, '1917');
      final parsed = cleaner.parse('2012 (2009)', ContentKind.movie);
      expect(parsed.title, '2012');
      expect(parsed.year, 2009);
    });

    test('garde une année future dans le titre', () {
      final parsed = cleaner.parse('Blade Runner 2049', ContentKind.movie);
      expect(parsed.title, 'Blade Runner 2049');
      expect(parsed.year, isNull);
    });

    test('garde les titres proches d une étiquette', () {
      expect(
        cleaner.parse('Stand by Me', ContentKind.movie).title,
        'Stand by Me',
      );
      expect(
        cleaner.parse("Stephen King's IT", ContentKind.movie).title,
        "Stephen King's IT",
      );
      expect(
        cleaner.parse('It: Chapter Two', ContentKind.movie).title,
        'It: Chapter Two',
      );
    });

    test('retire les préfixes de plateforme', () {
      expect(
        cleaner.parse('NF - The Crown', ContentKind.movie).title,
        'The Crown',
      );
    });
  });

  group('séries', () {
    final markers = <String, (int, int)>{
      'FR - Breaking Bad S01 E02': (1, 2),
      'Breaking Bad S1E2': (1, 2),
      'Breaking Bad 1x02': (1, 2),
      'Breaking Bad Saison 1 Épisode 2': (1, 2),
      'Breaking Bad Season 1 Episode 2': (1, 2),
    };
    markers.forEach((raw, expected) {
      test(raw, () {
        final parsed = cleaner.parse(raw, ContentKind.series);
        expect(parsed.title, 'Breaking Bad');
        expect(parsed.season, expected.$1);
        expect(parsed.episode, expected.$2);
      });
    });

    test('lit les mentions placées après le marqueur', () {
      final parsed = cleaner.parse(
        'Breaking Bad (2008) S01E02 VOSTFR',
        ContentKind.series,
      );
      expect(parsed.title, 'Breaking Bad');
      expect(parsed.year, 2008);
      expect(parsed.language, 'VOSTFR');
    });

    test('garde le titre de l épisode', () {
      final parsed = cleaner.parse('Lost S01E01 Pilot', ContentKind.series);
      expect(parsed.episodeTitle, 'Pilot');
    });

    test('ne confond pas une résolution avec un épisode', () {
      expect(cleaner.hasEpisodeMarker('Film 1920x1080'), isFalse);
    });

    test('isole le nom de série d origine', () {
      expect(cleaner.seriesNameOf('FR - Lost S01E01'), 'FR - Lost');
    });
  });

  group('groupes', () {
    test('retire pays et qualité', () {
      final parsed = cleaner.parseGroup('FRANCE SPORT HD');
      expect(parsed.displayName, 'SPORT');
      expect(parsed.key, 'sport');
      expect(parsed.countryCode, 'FR');
    });

    test('lit le préfixe', () {
      final parsed = cleaner.parseGroup('UK | ENTERTAINMENT');
      expect(parsed.displayName, 'ENTERTAINMENT');
      expect(parsed.countryCode, 'GB');
    });

    test('fusionne les groupes qui ne diffèrent que par la qualité', () {
      expect(
        cleaner.parseGroup('FRANCE FHD').key,
        cleaner.parseGroup('FRANCE SD').key,
      );
      expect(cleaner.parseGroup('FRANCE FHD').displayName, isEmpty);
    });

    test('extrait la langue d un groupe', () {
      final parsed = cleaner.parseGroup('SERIES FR');
      expect(parsed.displayName, 'SERIES');
      expect(parsed.language, 'FR');
    });
  });
}
