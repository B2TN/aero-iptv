import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/components/progress_track.dart';
import '../../../design_system/tokens/aero_look.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../l10n/version_names.dart';
import '../../player/playback_time.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(10));

/// Ce que le catalogue ajoute à une reprise : le titre de l'épisode et la
/// version regardée, telle que le fournisseur la nomme (`FR`, `4K-DE`).
typedef ContinueInfo = ({
  String? episodeTitle,
  String? version,
  String? variant,
});

/// Titre d'épisode et version d'une reprise. Une reprise que le catalogue ne
/// connaît plus garde sa carte, sans ces deux lignes.
final continueInfoProvider = FutureProvider.autoDispose
    .family<
      ContinueInfo,
      ({int sourceId, String contentKey, ContentKind kind})
    >((ref, key) async {
      const none = (episodeTitle: null, version: null, variant: null);
      final catalog = ref.watch(catalogRepositoryProvider);
      switch (key.kind) {
        case ContentKind.movie:
          final movie = await catalog.movieByContentKey(
            key.sourceId,
            key.contentKey,
          );
          return (
            episodeTitle: null,
            version: movie?.languageTag,
            variant: null,
          );
        case ContentKind.series:
          final found = await catalog.episodeByContentKey(
            key.sourceId,
            key.contentKey,
          );
          if (found == null) return none;
          final (series, episode) = found;
          final version = (await catalog.versionsOf(
            key.sourceId,
            series.groupingKey,
          )).where((v) => v.seriesEntryId == episode.seriesEntryId).firstOrNull;
          return (
            // Sans titre propre, le fournisseur répète celui de la série.
            episodeTitle: episode.title == series.title ? null : episode.title,
            version: version?.label,
            variant: version?.variant,
          );
        case ContentKind.live:
          return none;
      }
    });

/// Carte de « Continuer à regarder », sur deux emplacements : l'affiche à
/// gauche ; à droite le titre, l'épisode, la version regardée, le temps vu
/// sur la durée et sa barre.
class ContinueCard extends ConsumerWidget {
  const ContinueCard({
    required this.item,
    required this.focused,
    this.progressColor = AeroColors.progressStart,
    super.key,
  });

  final WatchProgress item;
  final bool focused;
  final Color progressColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final performance = AeroLook.of(context).isPerformance;
    final info = ref
        .watch(
          continueInfoProvider((
            sourceId: item.sourceId,
            contentKey: item.contentKey,
            kind: item.kind,
          )),
        )
        .value;
    final season = item.season;
    final number = item.episode;
    final version = info?.version;
    // Un libellé sans langue reconnue serait le titre brut du fournisseur.
    final versionLabel = version != null && isProviderLabel(version)
        ? versionName(
            version,
            l10n,
            ref.read(settingsProvider).languageCode,
            variant: info?.variant,
          )
        : null;
    // Un épisode suivant pas encore commencé n'a ni position ni durée.
    final started = item.duration > Duration.zero;
    final caption = AeroText.caption.copyWith(shadows: const []);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: performance ? PerformanceColors.panel : const Color(0x990A2443),
        borderRadius: _radius,
        border: Border.all(
          color: performance
              ? PerformanceColors.panelBorder
              : const Color(0x4DBFE6FA),
        ),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: AeroMetrics.cardWidth,
              child: PosterImage(
                url: item.posterUrl,
                decodeWidth: 240,
                placeholder: const ColoredBox(color: Color(0x66174470)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AeroText.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: focused ? AeroColors.leaf : AeroColors.foam,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (season != null && number != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.homeEpisodeNumber(season, number),
                        style: caption.copyWith(
                          color: AeroColors.aqua,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (info?.episodeTitle case final title?)
                        Text(
                          title,
                          style: caption.copyWith(color: AeroColors.foam),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                    if (versionLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        versionLabel,
                        style: caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      started
                          ? '${formatPlaybackTime(item.position)} / '
                                '${formatPlaybackTime(item.duration)}'
                          : l10n.homeUpNext,
                      style: caption.copyWith(color: AeroColors.foam),
                      maxLines: 1,
                    ),
                    if (started) ...[
                      const SizedBox(height: 5),
                      ProgressTrack(
                        fraction: item.fraction,
                        color: progressColor,
                        height: 7,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
