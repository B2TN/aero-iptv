import 'package:iptv_domain/iptv_domain.dart';

import 'generated/app_localizations.dart';
import 'language_names.dart';

/// Nom d'une version, d'après la langue de son audio : « Français »,
/// « Allemand 4K », « Allemand (sous-titré) ».
///
/// [label] est le libellé du fournisseur (`FR`, `4K-DE`, `DE SUB`). Un libellé
/// sans langue connue, comme `4K` ou `NF`, reste tel quel. [quality] s'ajoute
/// au nom s'il ne la cite pas déjà.
String versionName(
  String label,
  AppLocalizations l10n,
  String appLanguage, {
  String? variant,
  StreamQuality quality = StreamQuality.unknown,
}) {
  if (!isProviderLabel(label)) {
    return variant == null ? label : '$label ($variant)';
  }
  String? language;
  String? note;
  final others = <String>[];
  for (final token in labelTags(label)) {
    switch (token) {
      case 'SUB':
        note = l10n.versionSubtitled;
      case 'DUB':
        note = l10n.versionDubbed;
      case 'AI':
        note = 'IA';
      case final code when audioLanguageOfTag(code) != null:
        language ??=
            languageName(audioLanguageOfTag(code), appLanguage) ?? code;
      default:
        others.add(token);
    }
  }
  if (quality != StreamQuality.unknown && !others.contains(quality.label)) {
    others.add(quality.label);
  }
  final name = [?language, ...others].join(' ');
  final details = [?note, ?variant].join(', ');
  return details.isEmpty ? name : '$name ($details)';
}

/// Noms des versions d'un film, avec leur qualité : « Français 4K »,
/// « Français HD ». Le bouquet n'apparaît que pour distinguer deux versions
/// de même libellé et de même qualité.
List<String> movieVersionNames(
  List<Movie> movies,
  AppLocalizations l10n,
  String appLanguage,
) {
  String labelOf(Movie movie) => movie.languageTag ?? movie.rawTitle;
  String sameOf(Movie movie) => '${labelOf(movie)}|${movie.quality.name}';
  final counts = <String, int>{};
  for (final movie in movies) {
    counts.update(sameOf(movie), (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final movie in movies)
      versionName(
        labelOf(movie),
        l10n,
        appLanguage,
        quality: movie.quality,
        variant: counts[sameOf(movie)]! > 1 ? movie.category : null,
      ),
  ];
}
