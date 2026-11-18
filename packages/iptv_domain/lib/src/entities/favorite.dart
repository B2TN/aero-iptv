import 'content_kind.dart';

/// Film, série ou chaîne mis en favori.
///
/// [key] survit aux synchronisations et regroupe toutes les versions : la clé
/// de titre d'un film, la clé de regroupement d'une série ou d'une chaîne.
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
