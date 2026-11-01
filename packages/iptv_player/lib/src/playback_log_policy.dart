/// Suite à donner à un message d'erreur de mpv.
enum LogVerdict { ignore, failWhileStarting, fail, tryNextAudioTrack }

const int _maxDetailLength = 100;

final RegExp _url = RegExp(r'[a-z][a-z0-9+.-]*://\S*', caseSensitive: false);
final RegExp _path = RegExp(r'\S*/\S*/\S*');
final RegExp _spaces = RegExp(r'\s+');

/// Distingue une vraie panne d'une piste illisible.
///
/// Un flux compte souvent plusieurs pistes : celle qu'aucun décodeur ne sait
/// lire, TrueHD par exemple, n'empêche pas de lire les autres.
abstract final class PlaybackLogPolicy {
  static LogVerdict judge({
    required String prefix,
    required String level,
    required String text,
  }) {
    if (level == 'fatal') {
      return prefix == 'cplayer' ? LogVerdict.fail : LogVerdict.ignore;
    }
    if (level != 'error') return LogVerdict.ignore;
    return switch (prefix) {
      'ad' => LogVerdict.tryNextAudioTrack,
      'cplayer' when !_isTrackProblem(text) => LogVerdict.failWhileStarting,
      'file' || 'stream' => LogVerdict.failWhileStarting,
      'ffmpeg' when text.startsWith('tcp:') => LogVerdict.failWhileStarting,
      _ => LogVerdict.ignore,
    };
  }

  /// La vidéo continue sans le son ou sans les sous-titres concernés.
  static bool _isTrackProblem(String text) {
    final lower = text.toLowerCase();
    return lower.contains('audio device') ||
        lower.contains('subtitle') ||
        lower.contains('external file');
  }

  /// Motif affichable, sans URL : celles des flux contiennent le mot de passe.
  static String? detailOf(String text) {
    final cleaned = text
        .replaceAll(_url, '')
        .replaceAll(_path, '')
        .replaceAll(_spaces, ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length <= _maxDetailLength
        ? cleaned
        : cleaned.substring(0, _maxDetailLength);
  }
}
