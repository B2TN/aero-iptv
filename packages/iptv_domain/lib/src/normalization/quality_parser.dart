import '../entities/stream_quality.dart';

final RegExp _uhd = RegExp(r'^(?:(?:UHD|4K|8K)\d?|(?:2160|3840)[PI]?)$');
final RegExp _fhd = RegExp(r'^(?:FHD\d?|FULLHD|1080[PI]?)$');
final RegExp _hd = RegExp(r'^(?:HD\d?\+?|HDTV|HQ|720[PI]?)$');

/// Le suffixe est obligatoire ici : « Canal+ Sport 360 » est un nom de chaîne.
final RegExp _sd = RegExp(r'^(?:SD\d?|SDTV|LQ|(?:360|480|576)[PI])$');

/// Reconnaît les mentions de qualité dans un nom de flux.
abstract final class QualityParser {
  /// Retourne la qualité désignée par [token], insensible à la casse.
  static StreamQuality fromToken(String token) {
    final upper = token.toUpperCase();
    if (_uhd.hasMatch(upper)) return StreamQuality.uhd;
    if (_fhd.hasMatch(upper)) return StreamQuality.fhd;
    if (_hd.hasMatch(upper)) return StreamQuality.hd;
    if (_sd.hasMatch(upper)) return StreamQuality.sd;
    return StreamQuality.unknown;
  }
}
