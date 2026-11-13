/// Lecteurs tolérants : selon les panneaux Xtream, un même champ arrive sous
/// forme de nombre ou de chaîne, et un champ vide vaut `null` ou `""`.
int? readInt(Object? value) => switch (value) {
  final int number => number,
  final double number => number.toInt(),
  final String text => int.tryParse(text.trim()),
  _ => null,
};

String? readString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// Catégorie Xtream.
final class XtreamCategory {
  const XtreamCategory({required this.id, required this.name});

  factory XtreamCategory.fromJson(Map<String, dynamic> json) => XtreamCategory(
    id: readString(json['category_id']) ?? '',
    name: readString(json['category_name']) ?? '',
  );

  final String id;
  final String name;
}

/// Résumé, genre et durée d'un film ou d'une série, lus dans le bloc `info`
/// de `get_vod_info` ou de `get_series_info`.
final class XtreamTitleInfo {
  const XtreamTitleInfo({this.overview, this.genre, this.runtimeMinutes});

  /// Lit le bloc `info`. Certains panneaux envoient une liste vide à la place
  /// d'un objet quand ils ne savent rien.
  factory XtreamTitleInfo.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const XtreamTitleInfo();
    final seconds = readInt(json['duration_secs']);
    return XtreamTitleInfo(
      overview: readOverview(json['plot']) ?? readOverview(json['description']),
      genre: readString(json['genre']),
      runtimeMinutes: seconds != null && seconds > 0
          ? (seconds / 60).round()
          : _positive(readInt(json['episode_run_time'])),
    );
  }

  final String? overview;
  final String? genre;
  final int? runtimeMinutes;

  static int? _positive(int? value) =>
      value != null && value > 0 ? value : null;
}

/// Résumé lisible, ou `null` pour les textes de remplissage des panneaux.
String? readOverview(Object? value) {
  final text = readString(value)?.replaceAll(RegExp(r'\s+'), ' ');
  if (text == null || text.length < 3) return null;
  return switch (text.toLowerCase()) {
    'n/a' || 'null' || 'none' || 'no description' => null,
    _ => text,
  };
}

/// Réponse de `get_series_info` : la série et ses épisodes.
final class XtreamSeriesInfo {
  const XtreamSeriesInfo({required this.info, required this.episodes});

  factory XtreamSeriesInfo.fromJson(Map<String, dynamic> json) =>
      XtreamSeriesInfo(
        info: XtreamTitleInfo.fromJson(json['info']),
        episodes: XtreamEpisode.listFromSeriesInfo(json),
      );

  final XtreamTitleInfo info;
  final List<XtreamEpisode> episodes;
}

/// Épisode retourné par `get_series_info`.
final class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.extension,
    this.overview,
  });

  final int id;
  final int season;
  final int number;
  final String title;
  final String extension;
  final String? overview;

  /// Lit la réponse de `get_series_info`.
  ///
  /// `episodes` est une table indexée par saison, ou une liste de listes sur
  /// certains panneaux. Une entrée sans identifiant est ignorée.
  static List<XtreamEpisode> listFromSeriesInfo(Map<String, dynamic> json) {
    final raw = json['episodes'];
    final seasons = switch (raw) {
      final Map<String, dynamic> map => map.values,
      final List<dynamic> list => list,
      _ => const <Object?>[],
    };
    return [
      for (final season in seasons)
        if (season is List)
          for (final episode in season)
            if (episode is Map<String, dynamic> &&
                readInt(episode['id']) != null)
              XtreamEpisode(
                id: readInt(episode['id'])!,
                season: readInt(episode['season']) ?? 1,
                number: readInt(episode['episode_num']) ?? 0,
                title: readString(episode['title']) ?? '',
                extension: readString(episode['container_extension']) ?? 'mp4',
                overview: switch (episode['info']) {
                  final Map<String, dynamic> info => readOverview(info['plot']),
                  _ => null,
                },
              ),
    ];
  }
}
