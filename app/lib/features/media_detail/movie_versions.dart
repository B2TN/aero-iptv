import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';

/// Versions de la fiche de [movie] : la langue de l'application d'abord,
/// puis la meilleure qualité. Sans regroupement des films, chaque version
/// est un film à part : [movie] seul.
Future<List<Movie>> movieVersionsOf(
  WidgetRef ref,
  int sourceId,
  Movie movie,
) async {
  final settings = ref.read(settingsProvider);
  if (!settings.groupMovies) return [movie];
  final movies = await ref.read(catalogRepositoryProvider).moviesByGroupingKeys(
    sourceId,
    {movie.groupingKey},
  );
  if (movies.isEmpty) return [movie];
  return movieVersionsByLanguage(movies, settings.languageCode);
}
