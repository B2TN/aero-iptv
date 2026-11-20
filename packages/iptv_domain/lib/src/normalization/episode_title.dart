import 'text_folding.dart';

/// Marqueur d'épisode : `S01E02`, `S1 E2`, `1x02`.
final RegExp _marker = RegExp(
  r'\bS\d{1,3}[\s._-]*E\d{1,4}\b|\b\d{1,2}x\d{2,3}\b',
  caseSensitive: false,
);

/// Séparateurs laissés en tête ou en fin par le fournisseur.
final RegExp _edges = RegExp(r'^[\s|:._–—-]+|[\s|:._–—-]+$');

/// Titre générique, qui n'apprend rien : « Episode 3 », « Épisode 03 ».
final RegExp _generic = RegExp(
  r'^(?:[ée]pisode|episodio|folge|ep\.?)\s*\d+$',
  caseSensitive: false,
);

/// Titre propre d'un épisode, tel qu'on l'affiche après son numéro.
///
/// Beaucoup de fournisseurs écrivent tout dans le titre :
/// « EN - Dexter (2006) - S01E02 - Crocodile ». Seul ce qui suit le marqueur
/// d'épisode est gardé. `null` quand il ne reste rien d'utile : un titre vide,
/// celui de la série, ou un simple « Épisode 2 ».
String? episodeTitleOf(String? raw, String seriesTitle) {
  if (raw == null) return null;
  var title = raw.trim();
  final marker = _marker.allMatches(title).lastOrNull;
  if (marker != null) title = title.substring(marker.end);
  title = title.replaceAll(_edges, '');
  if (title.isEmpty || _generic.hasMatch(title)) return null;
  return lowerWithoutDiacritics(title) == lowerWithoutDiacritics(seriesTitle)
      ? null
      : title;
}
