import '../normalization/grouping_key.dart';
import 'content_kind.dart';
import 'stream_locator.dart';

/// Identité d'un contenu commune à toutes ses versions (VF, VO, VOSTFR…).
abstract final class WorkKeys {
  /// Un film : son titre normalisé, partagé par ses versions.
  static String movie(String title) => 'm:${GroupingKey.of(title)}';

  /// Un épisode : sa série, sa saison et son numéro.
  static String episode(String seriesKey, int season, int number) =>
      'e:$seriesKey:$season:$number';
}

/// Position de lecture d'une version d'un film ou d'un épisode.
final class WatchProgress {
  const WatchProgress({
    required this.sourceId,
    required this.contentKey,
    required this.kind,
    required this.title,
    required this.position,
    required this.duration,
    required this.updatedAt,
    required this.locator,
    this.posterUrl,
    this.workKey,
    this.seriesKey,
    this.season,
    this.episode,
    this.finished = false,
  });

  final int sourceId;

  /// Identité stable de cette version : elle survit au remplacement du
  /// catalogue.
  final String contentKey;
  final ContentKind kind;
  final String title;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  /// Permet de reprendre la lecture sans chercher le contenu dans le catalogue.
  final StreamLocator locator;
  final String? posterUrl;

  /// Identité commune aux versions, voir [WorkKeys]. `null` pour une reprise
  /// enregistrée avant qu'elle n'existe, si son contenu a quitté le catalogue.
  final String? workKey;

  /// Clé de regroupement de la série, pour un épisode.
  final String? seriesKey;
  final int? season;
  final int? episode;

  /// Vu jusqu'au bout : la reprise sert alors à marquer le contenu comme vu,
  /// et à proposer l'épisode suivant.
  final bool finished;

  /// Ce qui ne fait qu'une entrée dans « Continuer à regarder » : la série,
  /// sinon le contenu toutes versions confondues, sinon le fichier.
  String get groupKey => seriesKey ?? workKey ?? contentKey;

  WatchProgress copyWith({
    String? contentKey,
    Duration? position,
    Duration? duration,
    StreamLocator? locator,
    String? workKey,
    int? season,
    int? episode,
    bool? finished,
  }) => WatchProgress(
    sourceId: sourceId,
    contentKey: contentKey ?? this.contentKey,
    kind: kind,
    title: title,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    updatedAt: updatedAt,
    locator: locator ?? this.locator,
    posterUrl: posterUrl,
    workKey: workKey ?? this.workKey,
    seriesKey: seriesKey,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    finished: finished ?? this.finished,
  );
}
