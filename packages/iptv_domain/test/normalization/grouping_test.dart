import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  group('GroupingKey', () {
    test('ignore la casse, les accents et la ponctuation', () {
      expect(GroupingKey.of('Télé-Loisirs'), GroupingKey.of('TELE LOISIRS'));
    });

    test('distingue Canal+ de Canal', () {
      expect(GroupingKey.of('Canal+'), isNot(GroupingKey.of('Canal')));
      expect(
        GroupingKey.of('Canal+ Sport'),
        GroupingKey.of('Canal Plus Sport'),
      );
    });

    test('distingue un décalage horaire', () {
      expect(GroupingKey.of('E4 +1'), isNot(GroupingKey.of('E4')));
    });

    test('unifie & et and', () {
      expect(
        GroupingKey.of('Fast & Furious'),
        GroupingKey.of('Fast and Furious'),
      );
    });

    test('conserve les alphabets non latins', () {
      expect(GroupingKey.of('الجزيرة'), 'الجزيرة');
    });
  });

  group('CountryResolver', () {
    const resolver = CountryResolver();

    test('privilégie tvg-country', () {
      expect(resolver.resolve(tvgCountry: 'BE;FR', groupCountry: 'FR'), 'BE');
    });

    test('lit le groupe, puis le nom, puis tvg-id', () {
      expect(resolver.resolve(groupCountry: 'DE', nameCountry: 'FR'), 'DE');
      expect(resolver.resolve(nameCountry: 'FR', tvgId: 'x.de'), 'FR');
      expect(resolver.resolve(tvgId: 'BBCOne.uk'), 'GB');
      expect(resolver.resolve(tvgId: 'TF1.fr@SD'), 'FR');
    });

    test('retourne null sans indice', () {
      expect(resolver.resolve(), isNull);
    });
  });

  group('CountryCatalog', () {
    test('reconnaît les noms avec ou sans accent', () {
      expect(CountryCatalog.fromText('ALGÉRIE SPORT'), 'DZ');
      expect(CountryCatalog.fromText('algerie sport'), 'DZ');
    });

    test('préfère le nom le plus long', () {
      expect(CountryCatalog.fromText('AFRIQUE DU SUD'), 'ZA');
      expect(CountryCatalog.fromText('LATIN AMERICA'), 'LAT');
    });

    test('distingue l arabe de l Argentine', () {
      expect(CountryCatalog.fromPrefix('AR'), 'ARB');
      expect(CountryCatalog.fromPrefix('ARG'), 'AR');
      expect(CountryCatalog.fromTvgId('Telefe.ar'), 'AR');
    });
  });

  group('foldDecorations', () {
    test('replie les lettres décoratives', () {
      expect(foldDecorations('ᶠᴴᴰ ᵁᴴᴰ ⁴ᴷ'), 'FHD UHD 4K');
    });

    test('replie le gras mathématique', () {
      expect(foldDecorations('𝐅𝐇𝐃'), 'FHD');
    });

    test('transforme un drapeau en étiquette', () {
      expect(foldDecorations('🇫🇷 TF1'), '[FR] TF1');
    });
  });

  group('ResolveStreamUrl', () {
    test('construit une URL Xtream', () {
      final url = ResolveStreamUrl.buildXtreamUrl(
        const XtreamCredentials(
          serverUrl: 'http://s.example:8080/',
          username: 'jean dupont',
          password: 'p@ss/1',
        ),
        const XtreamStream(
          namespace: XtreamNamespace.movie,
          streamId: 42,
          extension: 'mkv',
        ),
      );
      expect(
        url,
        'http://s.example:8080/movie/jean%20dupont/p%40ss%2F1/42.mkv',
      );
    });

    test('accepte une adresse sans schéma ou avec son chemin d API', () {
      expect(
        ResolveStreamUrl.normalizeXtreamServer('s.example:8080'),
        'http://s.example:8080',
      );
      expect(
        ResolveStreamUrl.normalizeXtreamServer(
          'https://s.example/player_api.php?username=u',
        ),
        'https://s.example',
      );
    });

    test('ne retient que la première de plusieurs adresses', () {
      for (final input in [
        'http://s.example;',
        ' http://s.example/\nhttp://t.example',
        'http://s.example http://t.example',
        'http://s.example;http://t.example',
        '; http://s.example,',
      ]) {
        expect(
          ResolveStreamUrl.normalizeXtreamServer(input),
          'http://s.example',
        );
      }
    });
  });

  group('PlaylistCredentials', () {
    test('survit à un aller-retour par le coffre', () {
      const original = XtreamCredentials(
        serverUrl: 'http://s.example',
        username: 'u',
        password: 'p',
      );
      final restored = PlaylistCredentials.fromMap(original.toMap());
      expect(restored, isA<XtreamCredentials>());
      expect((restored as XtreamCredentials).password, 'p');
    });
  });
}
