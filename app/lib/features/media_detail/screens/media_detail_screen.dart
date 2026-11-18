import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/aero_states.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../../focus/focus_guard.dart';
import '../../../l10n/version_names.dart';
import '../../player/player_target.dart';
import '../widgets/detail_parts.dart';
import '../widgets/episode_lines.dart';

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

/// Ce qui a été vu de la série, toutes versions confondues, relu après
/// chaque lecture.
final _progressProvider = FutureProvider.autoDispose
    .family<SeriesProgress, ({int sourceId, String seriesKey})>((
      ref,
      key,
    ) async {
      ref.watch(watchedRevisionProvider);
      return SeriesProgress(
        await ref
            .watch(watchProgressRepositoryProvider)
            .progressOf(key.sourceId, key.seriesKey),
      );
    });

/// Épisode à reprendre, et la position où la lecture s'était arrêtée.
typedef EpisodeResume = ({Episode episode, Duration position});

/// Saisons et épisodes d'une version de série. Le bouton « Version » passe à
/// une autre sans quitter la fiche ; la reprise et les positions des épisodes
/// valent pour toutes les versions.
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

  /// Version montrée à l'ouverture.
  final int seriesEntryId;

  /// Ouverte depuis « Continuer à regarder » : la fiche propose de reprendre
  /// dès la première image, le bouton a le focus.
  final EpisodeResume? resume;

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  final FocusNode _backNode = FocusNode(debugLabel: 'DetailBack');
  final FocusNode _versionNode = FocusNode(debugLabel: 'DetailVersion');

  /// Après un changement de version, le focus reste sur le bouton Version :
  /// la nouvelle liste d'épisodes ne le prend pas.
  bool _versionChanged = false;

  /// Version montrée.
  late int _entryId = widget.seriesEntryId;

  /// Les versions de la série, connues une fois chargées.
  List<MediaVersion> _versions = const [];

  /// `null` tant que les saisons ne sont pas connues : la première est alors
  /// celle de l'épisode à reprendre.
  int? _season;

  /// Saison à rouvrir après un changement de version.
  int? _wantedSeason;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void dispose() {
    _backNode.dispose();
    _versionNode.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    final settings = ref.read(settingsProvider);
    // Sans regroupement, chaque version est une série à part.
    if (!settings.groupSeries) return;
    final all = await ref
        .read(catalogRepositoryProvider)
        .versionsOf(widget.sourceId, widget.series.groupingKey);
    if (!mounted) return;
    setState(
      () => _versions = versionsByLanguage(
        all,
        (version) => version.label,
        settings.languageCode,
      ),
    );
  }

  String _versionName(MediaVersion version) => versionName(
    version.label,
    context.l10n,
    ref.read(settingsProvider).languageCode,
    variant: version.variant,
  );

  Future<void> _chooseVersion() async {
    final picked = await showAeroMenu(
      context,
      title: context.l10n.detailChooseVersion,
      options: [for (final version in _versions) _versionName(version)],
    );
    if (picked == null || !mounted) return;
    final entryId = _versions[picked].seriesEntryId;
    if (entryId == _entryId) return;
    final shown = ref
        .read(_seasonsProvider((sourceId: widget.sourceId, entryId: _entryId)))
        .value;
    final season = _season;
    setState(() {
      // La même saison, si la nouvelle version l'a.
      _wantedSeason = shown == null || shown.isEmpty || season == null
          ? null
          : shown[season.clamp(0, shown.length - 1)].number;
      _season = null;
      _entryId = entryId;
      _versionChanged = true;
    });
    _versionNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = (sourceId: widget.sourceId, entryId: _entryId);
    final seasons = ref.watch(_seasonsProvider(key));
    final details = ref.watch(_detailsProvider(key)).value ?? TitleDetails.none;
    final progress = ref.watch(
      _progressProvider((
        sourceId: widget.sourceId,
        seriesKey: widget.series.groupingKey,
      )),
    );
    // Sans positions lisibles, la fiche reste utilisable, sans reprise.
    final seen = switch (progress) {
      AsyncValue(:final value?) => value,
      AsyncError() => SeriesProgress(const []),
      _ => null,
    };
    final shownSeasons = seasons.value;
    final EpisodeResume? resume = seen == null || shownSeasons == null
        // En attendant : la reprise demandée, pour la version demandée.
        ? (_entryId == widget.seriesEntryId ? widget.resume : null)
        : switch (seen.resumeIn(shownSeasons)) {
            final found? => (episode: found.episode, position: found.position),
            null => null,
          };
    final current = _versions
        .where((version) => version.seriesEntryId == _entryId)
        .firstOrNull;
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
                    if (resume != null) ...[
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
                        autofocus: widget.resume != null,
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
                    if (_versions.length > 1) ...[
                      const SizedBox(height: 16),
                      AeroButton(
                        label: l10n.playerVersion,
                        focusNode: _versionNode,
                        onSelect: _chooseVersion,
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
                        if (current != null && _versions.length > 1)
                          _versionName(current),
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
                        data: (seasons) => seen == null
                            ? AeroLoading(label: l10n.loading)
                            : _buildSeasons(
                                seasons,
                                seen,
                                resume,
                                schedule?.upcoming ?? const [],
                                schedule?.lateAfter(seasons) ?? const [],
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

  Widget _buildSeasons(
    List<Season> seasons,
    SeriesProgress seen,
    EpisodeResume? resume,
    List<UpcomingEpisode> upcoming,
    List<UpcomingEpisode> late,
  ) {
    final l10n = context.l10n;
    if (seasons.isEmpty) {
      return AeroMessage(title: l10n.detailNoEpisodes, autofocus: false);
    }
    final resumed = resume?.episode;
    final selected = (_season ??= _seasonIndex(
      seasons,
      _wantedSeason ?? resumed?.season,
    )).clamp(0, seasons.length - 1);
    final season = seasons[selected];
    final resumedIndex = resumed == null
        ? -1
        : season.episodes.indexWhere(
            (episode) =>
                episode.season == resumed.season &&
                episode.number == resumed.number,
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
              itemBuilder: (context, index, focused) => SeasonLine(
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
              key: ValueKey((_entryId, season.number)),
              // Le bouton de reprise a le focus quand la fiche en propose un.
              autofocus: widget.resume == null && !_versionChanged,
              initialIndex: resumedIndex < 0 ? 0 : resumedIndex,
              itemCount: season.episodes.length,
              itemExtent: described ? 96 : 56,
              padding: const EdgeInsets.all(4),
              onSelect: (index) => _playEpisode(seen, season.episodes[index]),
              itemBuilder: (context, index, focused) {
                final episode = season.episodes[index];
                return EpisodeLine(
                  title: episodeLabel(l10n, widget.series, episode),
                  overview: episode.overview,
                  watched: seen.of(episode.season, episode.number),
                  focused: focused,
                );
              },
            ),
          ),
        ),
        if (upcoming.isNotEmpty || late.isNotEmpty) ...[
          const SizedBox(width: 18),
          SizedBox(
            width: 232,
            child: UpcomingPanel(episodes: upcoming, late: late),
          ),
        ],
      ],
    );
  }

  void _playEpisode(SeriesProgress seen, Episode episode) => openPlayer(
    context,
    episodeTarget(widget.sourceId, widget.series, episode, seen),
  );
}

/// Index de la saison [number], ou la première.
int _seasonIndex(List<Season> seasons, int? number) {
  final index = seasons.indexWhere((season) => season.number == number);
  return index < 0 ? 0 : index;
}
