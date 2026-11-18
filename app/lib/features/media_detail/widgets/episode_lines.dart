import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/progress_track.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Libellé d'un épisode : « Épisode 2 », suivi de son titre s'il en a un
/// autre que celui de la série.
String episodeLabel(AppLocalizations l10n, Series series, Episode episode) {
  final label = l10n.detailEpisode(episode.number);
  return episode.title == series.title ? label : '$label : ${episode.title}';
}

/// Un épisode : son titre, et dessous son résumé quand il est connu. À
/// droite, la marque « vu », ou la barre d'avancement s'il est commencé, dans
/// n'importe quelle version. L'épisode en cours de lecture est précédé d'un
/// triangle de lecture.
class EpisodeLine extends StatelessWidget {
  const EpisodeLine({
    required this.title,
    required this.watched,
    required this.focused,
    this.overview,
    this.current = false,
    super.key,
  });

  final String title;
  final String? overview;
  final WatchProgress? watched;
  final bool focused;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = overview;
    final progress = watched;
    final Widget? status = progress == null
        ? null
        : progress.finished
        ? WatchedMark(label: l10n.detailWatched)
        : progress.inProgress
        ? SizedBox(
            width: 96,
            child: ProgressTrack(fraction: progress.fraction, height: 8),
          )
        : null;
    final heading = Row(
      children: [
        if (current) ...[
          Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: focused ? AeroColors.leaf : AeroColors.aqua,
            semanticLabel: l10n.playerNowPlaying,
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: AeroText.body.copyWith(
              color: focused
                  ? AeroColors.leaf
                  : current
                  ? AeroColors.aqua
                  : AeroColors.foam,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (status != null) ...[const SizedBox(width: 12), status],
      ],
    );
    if (summary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: heading,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          heading,
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

/// Une saison dans la liste des saisons ; [selected] est celle dont les
/// épisodes sont affichés.
class SeasonLine extends StatelessWidget {
  const SeasonLine({
    required this.text,
    required this.focused,
    this.selected = false,
    super.key,
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
