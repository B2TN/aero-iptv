import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/daily_sync.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/components/progress_track.dart';
import '../../../design_system/tokens/aero_look.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/version_names.dart';
import '../../player/playback_time.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

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

/// Quand arrive le prochain épisode : dans un mois au plus, en jours, sinon à
/// sa date. Déjà diffusé, il est attendu dans la playlist.
String nextEpisodeLabel(AppLocalizations l10n, DateTime airDate, DateTime now) {
  final days =
      (DateTime(
                airDate.year,
                airDate.month,
                airDate.day,
              ).difference(DateTime(now.year, now.month, now.day)).inHours /
              24)
          .round();
  if (days < 0) return l10n.homeNextEpisodeAired;
  if (days <= 30) return l10n.homeNextEpisodeIn(days);
  return l10n.homeNextEpisodeOn(
    DateFormat.MMMMd(l10n.localeName).format(airDate),
  );
}

/// Carte de « Continuer à regarder », sur deux emplacements : l'affiche à
/// gauche ; à droite le titre, l'épisode, la version regardée, le temps vu
/// sur la durée et sa barre.
class ContinueCard extends ConsumerWidget {
  const ContinueCard({
    required this.item,
    required this.focused,
    this.next,
    this.progressColor = AeroColors.progressStart,
    super.key,
  });

  final WatchProgress item;
  final bool focused;

  /// Série à jour : son prochain épisode annoncé, montré à la place de la
  /// reprise.
  final UpcomingEpisode? next;
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
    final next = this.next;
    final season = next?.season ?? item.season;
    final number = next?.number ?? item.episode;
    // Le titre de l'épisode vu ne vaut pas pour celui qui l'attend.
    final episodeTitle = next == null ? info?.episodeTitle : next.title;
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
    final started = next == null && item.duration > Duration.zero;
    final caption = AeroText.caption.copyWith(shadows: const []);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: performance ? PerformanceColors.panel : const Color(0xB3071E3A),
        borderRadius: _radius,
        border: Border.all(
          color: performance
              ? PerformanceColors.panelBorder
              : const Color(0x40EAF8FF),
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
                decodeWidth: 280,
                placeholder: const ColoredBox(color: Color(0x8C123E6E)),
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
                        color: AeroColors.foam,
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
                      if (episodeTitle case final title?)
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
                    if (next != null)
                      Text(
                        nextEpisodeLabel(
                          l10n,
                          next.airDate,
                          ref.read(clockProvider)(),
                        ),
                        style: caption.copyWith(
                          color: AeroColors.aqua,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
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
