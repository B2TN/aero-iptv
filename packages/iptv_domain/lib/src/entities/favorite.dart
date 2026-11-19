import 'content_kind.dart';

/// Film, série ou chaîne mis en favori.
///
/// [key] regroupe toutes les versions : la fiche d'un film ou d'une série,
/// la clé de regroupement d'une chaîne. Si la synchronisation regroupe
/// autrement un film ou une série, le favori suit sa fiche.
final class Favorite {
  const Favorite({
    required this.sourceId,
    required this.kind,
    required this.key,
    required this.title,
    required this.addedAt,
    this.posterUrl,
  });

  final int sourceId;
  final ContentKind kind;
  final String key;

  /// Titre et image au moment de l'ajout, montrés si le catalogue n'a plus le
  /// contenu.
  final String title;
  final String? posterUrl;
  final DateTime addedAt;
}
