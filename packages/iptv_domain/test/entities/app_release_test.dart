import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

AppVersion _v(String text) => AppVersion.tryParse(text)!;

AppRelease _release(String tag) => AppRelease(
  version: _v(tag),
  tag: tag,
  notes: '',
  pageUrl: 'https://github.com/B2TN/aero-iptv/releases/tag/$tag',
);

void main() {
  group('AppVersion', () {
    test('lit les étiquettes et les versions de pubspec', () {
      expect(_v('v0.2.1').toString(), '0.2.1');
      expect(_v('0.2.1-beta.3+20').toString(), '0.2.1-beta.3');
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('dernière'), isNull);
    });

    test('ordonne comme semver', () {
      final ordered = [
        '0.2.0',
        '0.2.1-beta.2',
        '0.2.1-beta.10',
        '0.2.1',
        '0.2.2-beta.1',
        '0.10.0',
      ].map(_v).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(ordered[i] > ordered[i - 1], isTrue, reason: '${ordered[i]}');
      }
      expect(_v('0.2.1') == _v('v0.2.1+18'), isTrue);
    });
  });

  group('findUpdate', () {
    final releases = [
      _release('v0.2.0'),
      _release('v0.2.1-beta.3'),
      _release('v0.2.1'),
      _release('v0.2.2-beta.1'),
    ];

    test('propose la release officielle la plus récente', () {
      final update = findUpdate(
        releases,
        current: _v('0.2.0'),
        preReleases: false,
      );
      expect(update?.tag, 'v0.2.1');
    });

    test('avec les mises à jour bêta, aussi les préversions', () {
      final update = findUpdate(
        releases,
        current: _v('0.2.1-beta.3'),
        preReleases: true,
      );
      expect(update?.tag, 'v0.2.2-beta.1');
    });

    test('rien de plus récent, ou la version écartée : rien', () {
      expect(
        findUpdate(releases, current: _v('0.2.1'), preReleases: false),
        isNull,
      );
      expect(
        findUpdate(
          releases,
          current: _v('0.2.0'),
          preReleases: false,
          dismissedTag: 'v0.2.1',
        ),
        isNull,
      );
    });
  });
}
