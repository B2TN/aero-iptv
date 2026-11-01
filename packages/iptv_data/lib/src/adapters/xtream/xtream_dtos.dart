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

/// Épisode retourné par `get_series_info`.
final class XtreamEpisode {
  const XtreamEpisode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    required this.extension,
  });

  final int id;
  final int season;
  final int number;
  final String title;
  final String extension;

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
              ),
    ];
  }
}
