import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_guard.dart';
import '../../player/player_target.dart';
import '../widgets/detail_parts.dart';

typedef _EntryKey = ({int sourceId, int entryId});

final _seasonsProvider = FutureProvider.autoDispose
    .family<List<Season>, _EntryKey>(
      (ref, key) => ref
          .watch(catalogRepositoryProvider)
          .seasonsOf(key.sourceId, key.entryId),
    );

/// Résumé et genre de la série. Sans réponse du fournisseur, la fiche reste
/// complète, simplement sans résumé.
final _detailsProvider = FutureProvider.autoDispose
    .family<TitleDetails, _EntryKey>((ref, key) async {
      try {
        return await ref
            .watch(catalogRepositoryProvider)
            .seriesDetails(key.sourceId, key.entryId);
      } on Failure {
        return TitleDetails.none;
      }
    });

/// Calendrier de diffusion. Il complète la fiche : sans TVmaze, elle n'en
/// montre simplement pas.
final _scheduleProvider = FutureProvider.autoDispose
    .family<ShowSchedule?, ({String title, int? year})>((ref, key) async {
      try {
        return await ref
            .watch(scheduleRepositoryProvider)
            .scheduleOf(key.title, year: key.year);
      } on Failure {
        return null;
      }
    });

/// Épisode à reprendre, et la position où la lecture s'était arrêtée.
typedef EpisodeResume = ({Episode episode, Duration position});

/// Saisons et épisodes d'une version de série.
class MediaDetailScreen extends ConsumerStatefulWidget {
  const MediaDetailScreen({
    required this.sourceId,
    required this.series,
    required this.seriesEntryId,
    this.resume,
    super.key,
  });

  final int sourceId;
  final Series series;
  final int seriesEntryId;

  /// Ouverte depuis « Continuer à regarder » : la fiche propose de reprendre,
  /// et s'ouvre sur la saison et l'épisode en cours.
  final EpisodeResume? resume;

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  final FocusNode _backNode = FocusNode(debugLabel: 'DetailBack');

  /// `null` tant que les saisons ne sont pas connues : la première est alors
  /// celle de l'épisode à reprendre.
  int? _season;

  @override
  void dispose() {
    _backNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = (sourceId: widget.sourceId, entryId: widget.seriesEntryId);
    final seasons = ref.watch(_seasonsProvider(key));
    final details = ref.watch(_detailsProvider(key)).value ?? TitleDetails.none;
    final schedule = ref
        .watch(
          _scheduleProvider((
            title: widget.series.title,
            year: widget.series.year,
          )),
        )
        .value;
    final seasonCount = seasons.value?.length ?? 0;
    return FocusGuard(
      fallback: () => _backNode,
      child: AeroCanvas(
        child: Padding(
          padding: const EdgeInsets.all(AeroMetrics.pagePadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AeroButton(
                      label: l10n.actionBack,
                      focusNode: _backNode,
                      onSelect: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 240,
                      height: 360,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(14),
                            ),
                            child: PosterImage(
                              url: widget.series.posterUrl,
                              decodeWidth: 480,
                            ),
                          ),
                          Image.asset(
                            AeroAssets.heroFrame,
                            centerSlice: const Rect.fromLTRB(20, 20, 44, 44),
                            scale: AeroAssets.scale,
                            fit: BoxFit.fill,
                          ),
                        ],
                      ),
                    ),
                    if (widget.resume case final resume?) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.detailResumeEpisode(
                          resume.episode.season,
                          resume.episode.number,
                        ),
                        style: AeroText.caption,
                      ),
                      const SizedBox(height: 8),
                      AeroButton(
                        label: l10n.detailResume,
                        icon: Icons.play_arrow,
                        tone: AeroTone.green,
                        autofocus: true,
                        onSelect: () => openPlayer(
                          context,
                          PlayerTarget.episode(
                            widget.sourceId,
                            widget.series,
                            resume.episode,
                          ).resumingAt(resume.position),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailHeader(
                      title: widget.series.title,
                      tags: [
                        if (widget.series.year case final year?) '$year',
                        ?details.genre,
                        if (seasonCount > 0)
                          l10n.detailSeasonCount(seasonCount),
                      ],
                      highlight: schedule?.running ?? false
                          ? l10n.detailRunning
                          : null,
                      overview: details.overview,
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: seasons.when(
                        loading: () => AeroLoading(label: l10n.loading),
                        error: (error, _) => AeroMessage(
                          title: l10n.loadErrorTitle,
                          actionLabel: l10n.actionBack,
                          onAction: () => Navigator.of(context).maybePop(),
                        ),
                        data: (seasons) => _buildSeasons(
                          seasons,
                          schedule?.upcoming ?? const [],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasons(List<Season> seasons, List<UpcomingEpisode> upcoming) {
    final l10n = context.l10n;
    if (seasons.isEmpty) {
      return AeroMessage(title: l10n.detailNoEpisodes, autofocus: false);
    }
    final resumed = widget.resume?.episode;
    final selected = (_season ??= _seasonOf(
      seasons,
      resumed,
    )).clamp(0, seasons.length - 1);
    final season = seasons[selected];
    final resumedIndex = resumed == null
        ? -1
        : season.episodes.indexWhere(
            (episode) => episode.contentKey == resumed.contentKey,
          );
    // Avec des résumés, chaque épisode prend deux lignes de plus.
    final described = season.episodes.any(
      (episode) => episode.overview != null,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 180,
          child: GlassPanel(
            padding: const EdgeInsets.all(12),
            child: DpadCollection.vertical(
              itemCount: seasons.length,
              itemExtent: 48,
              padding: const EdgeInsets.all(4),
              onIndexChanged: (index) => setState(() => _season = index),
              onSelect: (index) => setState(() => _season = index),
              initialIndex: selected,
              itemBuilder: (context, index, focused) => _Line(
                text: l10n.detailSeason(seasons[index].number),
                focused: focused,
                selected: index == selected,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: GlassPanel(
            padding: const EdgeInsets.all(12),
            child: DpadCollection.vertical(
              key: ValueKey(season.number),
              // Le bouton de reprise a le focus quand la fiche en propose un.
              autofocus: widget.resume == null,
              initialIndex: resumedIndex < 0 ? 0 : resumedIndex,
              itemCount: season.episodes.length,
              itemExtent: described ? 96 : 56,
              padding: const EdgeInsets.all(4),
              onSelect: (index) => openPlayer(
                context,
                PlayerTarget.episode(
                  widget.sourceId,
                  widget.series,
                  season.episodes[index],
                ),
              ),
              itemBuilder: (context, index, focused) {
                final episode = season.episodes[index];
                final label = l10n.detailEpisode(episode.number);
                return _EpisodeLine(
                  title: episode.title == widget.series.title
                      ? label
                      : '$label : ${episode.title}',
                  overview: episode.overview,
                  focused: focused,
                );
              },
            ),
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(width: 18),
          SizedBox(width: 232, child: UpcomingPanel(episodes: upcoming)),
        ],
      ],
    );
  }
}

/// Index de la saison de [episode], ou la première.
int _seasonOf(List<Season> seasons, Episode? episode) {
  if (episode == null) return 0;
  final index = seasons.indexWhere((season) => season.number == episode.season);
  return index < 0 ? 0 : index;
}

/// Un épisode : son titre, et dessous son résumé quand il est connu.
class _EpisodeLine extends StatelessWidget {
  const _EpisodeLine({
    required this.title,
    required this.overview,
    required this.focused,
  });

  final String title;
  final String? overview;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final summary = overview;
    if (summary == null) return _Line(text: title, focused: focused);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AeroText.body.copyWith(
              color: focused ? AeroColors.leaf : AeroColors.foam,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: AeroText.caption.copyWith(
              color: AeroColors.mist,
              height: 1.35,
              shadows: const [],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.text,
    required this.focused,
    this.selected = false,
  });

  final String text;
  final bool focused;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        style: AeroText.body.copyWith(
          color: focused
              ? AeroColors.leaf
              : selected
              ? AeroColors.aqua
              : AeroColors.foam,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
