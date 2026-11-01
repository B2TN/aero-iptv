import 'package:iptv_domain/iptv_domain.dart';

import 'generated/app_localizations.dart';
import 'language_names.dart';

/// Nom d'une version, d'après la langue de son audio : « Français »,
/// « Allemand 4K », « Allemand (sous-titré) ».
///
/// [label] est le libellé du fournisseur (`FR`, `4K-DE`, `DE SUB`). Un libellé
/// sans langue connue, comme `4K` ou `NF`, reste tel quel.
String versionName(
  String label,
  AppLocalizations l10n,
  String appLanguage, {
  String? variant,
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
  final name = [?language, ...others].join(' ');
  final details = [?note, ?variant].join(', ');
  return details.isEmpty ? name : '$name ($details)';
}

/// Noms des versions d'un film. Le bouquet n'apparaît que pour distinguer deux
/// versions de même libellé.
List<String> movieVersionNames(
  List<Movie> movies,
  AppLocalizations l10n,
  String appLanguage,
) {
  String labelOf(Movie movie) => movie.languageTag ?? movie.rawTitle;
  final counts = <String, int>{};
  for (final movie in movies) {
    counts.update(labelOf(movie), (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final movie in movies)
      versionName(
        labelOf(movie),
        l10n,
        appLanguage,
        variant: counts[labelOf(movie)]! > 1 ? movie.category : null,
      ),
  ];
}
