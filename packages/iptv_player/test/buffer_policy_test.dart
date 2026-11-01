import 'package:iptv_domain/iptv_domain.dart';
import 'package:iptv_player/src/live_buffer_policy.dart';
import 'package:iptv_player/src/memory_tier.dart';
import 'package:iptv_player/src/mpv_profile.dart';
import 'package:iptv_player/src/track_mapper.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:test/test.dart';

const ResolvedStream stream = ResolvedStream(url: 'http://s/1.ts');

Map<String, String> live(int delay) => LiveBufferPolicy.optionsFor(
  PlaybackRequest(stream: stream, isLive: true, liveDelaySeconds: delay),
  MemoryTier.low,
);

void main() {
  test('laisse au panneau le temps de libérer sa connexion', () {
    final vod = LiveBufferPolicy.optionsFor(
      const PlaybackRequest(
        stream: ResolvedStream(url: 'http://s/1.mkv'),
        isLive: false,
      ),
      MemoryTier.low,
    );

    expect(vod['network-timeout'], '20');
    expect(live(0)['network-timeout'], '20');
  });

  test('confie au relais l essentiel de la mise en réserve d une VOD', () {
    Map<String, String> vod(String url) => LiveBufferPolicy.optionsFor(
      PlaybackRequest(stream: ResolvedStream(url: url), isLive: false),
      MemoryTier.low,
    );

    expect(vod('http://s/1.mkv')['demuxer-max-bytes'], '${8 * 1024 * 1024}');
    // Une liste HLS ne passe pas par le relais : mpv garde son propre tampon.
    expect(vod('http://s/1.m3u8'), isNot(contains('demuxer-max-bytes')));
    expect(live(0), isNot(contains('demuxer-max-bytes')));
  });

  test(
    'la fenêtre du relais contient le tampon de mpv et ce qui le précède',
    () {
      for (final tier in MemoryTier.values) {
        final behind = tier.relayWindowBytes * 2 ~/ 3;
        const elevenSeconds = 11 * 10 * 1000 * 1000 ~/ 8;

        expect(behind, greaterThan(tier.relayedForwardBytes + elevenSeconds));
      }
    },
  );

  group('MpvProfile', () {
    final options = MpvProfile.base(MemoryTier.low);

    test('interdit le cache disque, qui remplirait le stockage', () {
      expect(options['cache-on-disk'], 'no');
      expect(options['cache'], 'yes');
    });

    test('impose le décodage audio logiciel', () {
      expect(options['audio-spdif'], '');
    });

    test('borne la mémoire selon l appareil', () {
      expect(options['demuxer-max-bytes'], '${32 * 1024 * 1024}');
      expect(options['demuxer-donate-buffer'], 'no');
      expect(
        MpvProfile.base(MemoryTier.desktop)['demuxer-max-bytes'],
        '${150 * 1024 * 1024}',
      );
    });
  });

  group('LiveBufferPolicy', () {
    test('démarre sans attente si le retard est nul', () {
      expect(live(0)['cache-pause-initial'], 'no');
      expect(live(0)['cache-pause-wait'], '1');
    });

    test('met en réserve le retard demandé avant de démarrer', () {
      final options = live(8);
      expect(options['cache-pause-initial'], 'yes');
      expect(options['cache-pause-wait'], '8');
      expect(options['cache-secs'], '10');
    });

    test('la lecture anticipée dépasse toujours la réserve', () {
      for (final delay in [0, 1, 5, 30]) {
        final options = live(delay);
        expect(
          int.parse(options['cache-secs']!),
          greaterThan(int.parse(options['cache-pause-wait']!)),
        );
      }
    });

    test('plafonne le retard', () {
      expect(live(500)['cache-pause-wait'], '$maxLiveDelaySeconds');
      expect(live(-5)['cache-pause-initial'], 'no');
    });

    test('ne garde aucun tampon arrière en direct', () {
      expect(live(5)['demuxer-max-back-bytes'], '0');
    });

    test('garde un tampon arrière en VOD et ignore le retard', () {
      final options = LiveBufferPolicy.optionsFor(
        const PlaybackRequest(
          stream: stream,
          isLive: false,
          liveDelaySeconds: 10,
        ),
        MemoryTier.low,
      );
      expect(options['demuxer-max-back-bytes'], '${4 * 1024 * 1024}');
      expect(options['cache-pause-initial'], 'yes');
      expect(options['cache-pause-wait'], '2');
    });
  });

  group('TrackMapper', () {
    test('retire les entrées techniques', () {
      final tracks = TrackMapper.audio([
        mk.AudioTrack.auto(),
        mk.AudioTrack.no(),
        mk.AudioTrack('1', 'VF', 'fre'),
      ]);
      expect(tracks.single.id, '1');
      expect(tracks.single.language, 'fre');
      expect(tracks.single.kind, MediaTrackKind.audio);
    });

    test('traduit les sous-titres', () {
      final tracks = TrackMapper.subtitle([
        mk.SubtitleTrack.no(),
        mk.SubtitleTrack('2', null, 'eng'),
      ]);
      expect(tracks.single.kind, MediaTrackKind.subtitle);
    });
  });
}
