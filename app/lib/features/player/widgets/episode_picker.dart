import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../focus/dpad_collection.dart';
import '../../media_detail/widgets/episode_lines.dart';

/// Choix d'un épisode depuis le lecteur : les saisons à gauche, leurs
/// épisodes à droite, avec ce qui a été vu ou commencé dans n'importe quelle
/// version. S'ouvre sur l'épisode en cours.
///
/// Retourne l'épisode choisi, ou `null` si l'utilisateur fait retour.
Future<Episode?> showEpisodePicker(
  BuildContext context, {
  required Series series,
  required List<Season> seasons,
  required Episode current,
  required SeriesProgress seen,
}) => showAeroOverlay<Episode>(
  context,
  label: context.l10n.playerEpisodes,
  builder: (context) => _EpisodePicker(
    series: series,
    seasons: seasons,
    current: current,
    seen: seen,
  ),
);

class _EpisodePicker extends StatefulWidget {
  const _EpisodePicker({
    required this.series,
    required this.seasons,
    required this.current,
    required this.seen,
  });

  final Series series;
  final List<Season> seasons;
  final Episode current;
  final SeriesProgress seen;

  @override
  State<_EpisodePicker> createState() => _EpisodePickerState();
}

class _EpisodePickerState extends State<_EpisodePicker> {
  /// Saison affichée : d'abord celle de l'épisode en cours.
  late int _season = math.max(
    0,
    widget.seasons.indexWhere(
      (season) => season.number == widget.current.season,
    ),
  );

  /// Les épisodes ne prennent le focus qu'à l'ouverture, sur l'épisode en
  /// cours. Quand l'utilisateur change de saison, le focus reste sur elle :
  /// il va lui-même vers ses épisodes.
  bool _seasonChanged = false;

  bool _isCurrent(Episode episode) =>
      episode.contentKey == widget.current.contentKey;

  void _showSeason(int index) {
    if (index == _season) return;
    setState(() {
      _season = index;
      _seasonChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seasons = widget.seasons;
    final season = seasons.isEmpty ? null : seasons[_season];
    final currentIndex = season?.episodes.indexWhere(_isCurrent) ?? -1;
    return Center(
      child: SizedBox(
        width: 860,
        height: 500,
        child: GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.playerEpisodes, style: AeroText.heading),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 190,
                      child: DpadCollection.vertical(
                        itemCount: seasons.length,
                        itemExtent: 48,
                        padding: const EdgeInsets.all(4),
                        initialIndex: _season,
                        onIndexChanged: _showSeason,
                        onSelect: _showSeason,
                        itemBuilder: (context, index, focused) => SeasonLine(
                          text: l10n.detailSeason(seasons[index].number),
                          focused: focused,
                          selected: index == _season,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (season != null)
                      Expanded(
                        child: DpadCollection.vertical(
                          key: ValueKey(season.number),
                          autofocus: !_seasonChanged,
                          initialIndex: math.max(0, currentIndex),
                          itemCount: season.episodes.length,
                          itemExtent: 56,
                          padding: const EdgeInsets.all(4),
                          onSelect: (index) =>
                              Navigator.of(context).pop(season.episodes[index]),
                          itemBuilder: (context, index, focused) {
                            final episode = season.episodes[index];
                            return EpisodeLine(
                              title: episodeLabel(l10n, widget.series, episode),
                              watched: widget.seen.of(
                                episode.season,
                                episode.number,
                              ),
                              focused: focused,
                              current: _isCurrent(episode),
                            );
                          },
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
}
