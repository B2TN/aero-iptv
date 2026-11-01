import 'package:iptv_player/src/playback_log_policy.dart';
import 'package:test/test.dart';

void main() {
  LogVerdict judge(String prefix, String level, String text) =>
      PlaybackLogPolicy.judge(prefix: prefix, level: level, text: text);

  group('PlaybackLogPolicy', () {
    test('une piste audio illisible ne fait pas échouer la lecture', () {
      expect(
        judge(
          'ad',
          'error',
          "Failed to initialize a decoder for codec 'truehd'.",
        ),
        LogVerdict.tryNextAudioTrack,
      );
    });

    test('un périphérique audio absent laisse la vidéo jouer', () {
      expect(
        judge(
          'cplayer',
          'error',
          'Could not open/initialize audio device -> no sound.',
        ),
        LogVerdict.ignore,
      );
    });

    test('un décodeur vidéo en échec laisse mpv décider', () {
      expect(judge('vd', 'error', 'Could not open codec.'), LogVerdict.ignore);
    });

    test('un flux introuvable fait échouer le démarrage', () {
      expect(
        judge('cplayer', 'error', 'Failed to recognize file format.'),
        LogVerdict.failWhileStarting,
      );
      expect(
        judge('ffmpeg', 'error', 'tcp: ffurl_read returned error'),
        LogVerdict.failWhileStarting,
      );
    });

    test('une erreur fatale de mpv arrête la lecture', () {
      expect(
        judge('cplayer', 'fatal', 'No video or audio streams selected.'),
        LogVerdict.fail,
      );
    });

    test('le motif affiché ne cite jamais l URL du flux', () {
      final detail = PlaybackLogPolicy.detailOf(
        'Failed to open http://s.example/series/jean/secret/1.mkv.',
      );
      expect(detail, 'Failed to open');
      expect(
        PlaybackLogPolicy.detailOf('Cannot open /series/jean/secret/1.mkv'),
        'Cannot open',
      );
    });
  });
}
