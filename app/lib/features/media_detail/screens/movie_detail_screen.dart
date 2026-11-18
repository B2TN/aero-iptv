import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../app/di/repository_providers.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_canvas.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/components/progress_track.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/focus_guard.dart';
import '../../../l10n/version_names.dart';
import '../../player/player_target.dart';
import '../widgets/detail_parts.dart';

/// Résumé, genre et durée d'une version du film. Sans réponse du fournisseur,
/// la fiche reste complète, simplement sans résumé.
final _detailsProvider = FutureProvider.autoDispose
    .family<TitleDetails, ({int sourceId, int movieId})>((ref, key) async {
      try {
        return await ref
            .watch(catalogRepositoryProvider)
            .movieDetails(key.sourceId, key.movieId);
      } on Failure {
        return TitleDetails.none;
      }
    });

/// Positions du film dans toutes ses versions, relues après chaque lecture.
final _progressProvider = FutureProvider.autoDispose
    .family<List<WatchProgress>, ({int sourceId, String workKey})>((ref, key) {
      ref.watch(watchedRevisionProvider);
      return ref
          .watch(watchProgressRepositoryProvider)
          .progressOf(key.sourceId, key.workKey);
    });

/// Position où reprendre un film d'après ses positions, la plus récente
/// d'abord : celle de la dernière version regardée, sauf s'il a été vu
/// jusqu'au bout.
Duration? movieResumeAt(List<WatchProgress> history) {
  final latest = history.firstOrNull;
  return latest == null || latest.finished || latest.position <= Duration.zero
      ? null
      : latest.position;
}

/// Fiche d'un film : reprise, lecture depuis le début et choix de la version.
/// La reprise vaut pour toutes les versions.
class MovieDetailScreen extends ConsumerStatefulWidget {
  const MovieDetailScreen({
    required this.sourceId,
    required this.movie,
    this.resumeAt,
    super.key,
  });

  final int sourceId;
  final Movie movie;

  /// Position où la lecture s'était arrêtée, toutes versions confondues : la
  /// fiche propose de reprendre dès la première image.
  final Duration? resumeAt;

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  final FocusNode _firstNode = FocusNode(debugLabel: 'MovieFirstAction');
  late Movie _movie = widget.movie;

  /// Les autres versions du film, connues une fois chargées.
  List<Movie> _versions = const [];

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void dispose() {
    _firstNode.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    // Sans regroupement, chaque version est un film à part.
    if (!ref.read(settingsProvider).groupMovies) return;
    final movies = await ref.read(catalogRepositoryProvider).moviesByTitleKeys(
      widget.sourceId,
      {GroupingKey.of(_movie.title)},
    );
    if (!mounted) return;
    final language = ref.read(settingsProvider).languageCode;
    setState(
      () => _versions = versionsByLanguage(
        movies,
        (version) => version.languageTag ?? version.rawTitle,
        language,
      ),
    );
  }

  void _play({Duration? at}) {
    final target = PlayerTarget.movie(widget.sourceId, _movie);
    openPlayer(context, at == null ? target : target.resumingAt(at));
  }

  Future<void> _chooseVersion() async {
    final l10n = context.l10n;
    final language = ref.read(settingsProvider).languageCode;
    final picked = await showAeroMenu(
      context,
      title: l10n.detailChooseVersion,
      options: movieVersionNames(_versions, l10n, language),
    );
    if (picked == null || !mounted) return;
    setState(() => _movie = _versions[picked]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final progress = ref.watch(
      _progressProvider((
        sourceId: widget.sourceId,
        workKey: WorkKeys.movie(_movie.title),
      )),
    );
    final resumeAt = progress.hasValue
        ? movieResumeAt(progress.requireValue)
        : widget.resumeAt;
    // La dernière version regardée dit où en est le film.
    final latest = progress.value?.firstOrNull;
    final year = _movie.year;
    final details =
        ref
            .watch(
              _detailsProvider((sourceId: widget.sourceId, movieId: _movie.id)),
            )
            .value ??
        TitleDetails.none;
    final runtime = details.runtime;
    return FocusGuard(
      fallback: () => _firstNode,
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
                              url: _movie.posterUrl,
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
                    if (latest != null && latest.inProgress) ...[
                      const SizedBox(height: 10),
                      ProgressTrack(fraction: latest.fraction),
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
                      title: _movie.title,
                      tags: [
                        ?year?.toString(),
                        ?details.genre,
                        if (runtime != null) runtimeLabel(l10n, runtime),
                        movieVersionNames(
                          [_movie],
                          l10n,
                          ref.read(settingsProvider).languageCode,
                        ).single,
                      ],
                      highlight: latest != null && latest.finished
                          ? l10n.detailWatched
                          : null,
                      overview: details.overview,
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        if (resumeAt != null)
                          AeroButton(
                            label: l10n.detailResume,
                            icon: Icons.play_arrow,
                            tone: AeroTone.green,
                            focusNode: _firstNode,
                            autofocus: true,
                            onSelect: () => _play(at: resumeAt),
                          ),
                        AeroButton(
                          label: resumeAt == null
                              ? l10n.detailPlay
                              : l10n.detailPlayFromStart,
                          icon: resumeAt == null ? Icons.play_arrow : null,
                          tone: resumeAt == null
                              ? AeroTone.green
                              : AeroTone.blue,
                          focusNode: resumeAt == null ? _firstNode : null,
                          autofocus: resumeAt == null,
                          onSelect: () => _play(
                            at: resumeAt == null ? null : Duration.zero,
                          ),
                        ),
                        if (_versions.length > 1)
                          AeroButton(
                            label: l10n.playerVersion,
                            onSelect: _chooseVersion,
                          ),
                      ],
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
}
