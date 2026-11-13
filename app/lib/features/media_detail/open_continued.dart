import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/di/repository_providers.dart';
import '../player/player_target.dart';
import 'screens/media_detail_screen.dart';
import 'screens/movie_detail_screen.dart';

/// Ouvre la fiche d'un élément de « Continuer à regarder ». La lecture se
/// reprend depuis la fiche.
///
/// Un contenu absent du catalogue actuel, par exemple retiré par le
/// fournisseur, n'a plus de fiche : la lecture reprend alors directement.
Future<void> openContinued(
  BuildContext context,
  WidgetRef ref,
  WatchProgress item,
) async {
  final navigator = Navigator.of(context);
  final catalog = ref.read(catalogRepositoryProvider);
  final Widget? page = switch (item.kind) {
    ContentKind.movie =>
      await catalog
          .movieByContentKey(item.sourceId, item.contentKey)
          .then(
            (movie) => movie == null
                ? null
                : MovieDetailScreen(
                    sourceId: item.sourceId,
                    movie: movie,
                    resumeAt: item.position,
                  ),
          ),
    ContentKind.series =>
      await catalog
          .episodeByContentKey(item.sourceId, item.contentKey)
          .then(
            (found) => found == null
                ? null
                : MediaDetailScreen(
                    sourceId: item.sourceId,
                    series: found.$1,
                    seriesEntryId: found.$2.seriesEntryId,
                    resume: (episode: found.$2, position: item.position),
                  ),
          ),
    ContentKind.live => null,
  };
  if (!context.mounted) return;
  if (page == null) {
    await navigator.push(playerRoute(PlayerTarget.resume(item)));
    return;
  }
  await navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => page,
    ),
  );
}
