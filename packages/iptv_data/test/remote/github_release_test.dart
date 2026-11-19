import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_data/iptv_data.dart';
import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

void main() {
  test('lit les releases, préversions comprises, sans les brouillons', () async {
    late http.Request asked;
    final repository = GithubReleaseRepository(
      MockClient((request) async {
        asked = request;
        return _json([
          {'tag_name': 'v0.2.2', 'draft': true, 'body': 'Brouillon'},
          {
            'tag_name': 'v0.2.1-beta.4',
            'prerelease': true,
            'body': '## Nouveautés\n- Épisodes',
            'html_url':
                'https://github.com/B2TN/aero-iptv/releases/tag/v0.2.1-beta.4',
            'assets': [
              {
                'name': 'aero-iptv-fire-tv-armeabi-v7a.apk',
                'browser_download_url': 'https://github.com/x.apk',
                'size': 30000000,
              },
            ],
          },
          {'tag_name': 'pas-une-version'},
        ]);
      }),
    );

    final releases = await repository.releases();

    expect(asked.url.host, 'api.github.com');
    expect(asked.url.path, '/repos/B2TN/aero-iptv/releases');
    // Rien qui désigne l'utilisateur : un agent générique.
    expect(asked.headers['User-Agent'], 'AeroIPTV');
    final release = releases.single;
    expect(release.tag, 'v0.2.1-beta.4');
    expect(release.isPreRelease, isTrue);
    // Le drapeau de GitHub compte, même sur un numéro sans suffixe.
    final flagged = await GithubReleaseRepository(
      MockClient(
        (_) async => _json([
          {'tag_name': 'v0.2.5', 'prerelease': true},
        ]),
      ),
    ).releases();
    expect(flagged.single.isPreRelease, isTrue);
    expect(release.notes, startsWith('## Nouveautés'));
    expect(release.assets['aero-iptv-fire-tv-armeabi-v7a.apk']?.size, 30000000);
  });

  test('signale la limite de l API', () async {
    final repository = GithubReleaseRepository(
      MockClient((_) async => _json({'message': 'rate limit'}, status: 403)),
    );

    await expectLater(repository.releases(), throwsA(isA<RateLimitFailure>()));
  });
}
