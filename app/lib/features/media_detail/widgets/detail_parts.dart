import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/art_backdrop.dart';
import '../../../design_system/components/meta_tag.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_look.dart';
import '../../../design_system/tokens/aero_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Prochains épisodes montrés au plus : la suite reste à venir.
const int _shownUpcoming = 3;

/// Durée lisible : « 42 min », ou « 1 h 42 » au-delà d'une heure.
String runtimeLabel(AppLocalizations l10n, Duration runtime) {
  final hours = runtime.inHours;
  final minutes = runtime.inMinutes % 60;
  return hours == 0
      ? l10n.detailRuntimeMinutes(minutes)
      : l10n.detailRuntimeHours(hours, minutes.toString().padLeft(2, '0'));
}

/// Jour de diffusion, par exemple « Jeudi 20 novembre ».
String airDateLabel(AppLocalizations l10n, DateTime day) {
  final text = DateFormat.MMMMEEEEd(l10n.localeName).format(day);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// Largeur du texte d'une fiche : l'image occupe le reste.
const double detailTextWidth = 640;

/// Fond d'une fiche : son image large fondue dans le ciel, en haut, du côté de
/// la fin de la ligne, et un voile qui garde le texte lisible.
class DetailBackdrop extends StatelessWidget {
  const DetailBackdrop({
    required this.imageUrl,
    required this.posterUrl,
    this.compactPoster = false,
    super.key,
  });

  final String? imageUrl;
  final String? posterUrl;

  /// Affiche plus petite, en haut : la fiche d'une série garde la place de
  /// ses épisodes.
  final bool compactPoster;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 470,
        child: ArtBackdrop(
          imageUrl: imageUrl,
          posterUrl: posterUrl,
          artShare: 0.72,
          textShare: 0.3,
          fadeFrom: 0.5,
          posterHeight: compactPoster ? 200 : 300,
          posterAlignment: compactPoster
              ? const AlignmentDirectional(0.7, -0.75)
              : const AlignmentDirectional(0.62, -0.05),
        ),
      ),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [Color(0x8C021229), Color(0x00021229)],
              stops: [0, 0.6],
            ),
          ),
        ),
      ),
    ],
  );
}

/// Titre d'une fiche, ses étiquettes et son résumé.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    required this.title,
    required this.tags,
    this.highlight,
    this.overview,
    this.overviewLines = 4,
    super.key,
  });

  final String title;

  /// Année, genre, durée ou nombre de saisons.
  final List<String> tags;

  /// Étiquette mise en avant, comme « En cours de diffusion ».
  final String? highlight;
  final String? overview;
  final int overviewLines;

  @override
  Widget build(BuildContext context) {
    final summary = overview;
    final accent = highlight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AeroText.display,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (tags.isNotEmpty || accent != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final tag in tags) MetaTag(text: tag),
              if (accent != null) MetaTag(text: accent, accent: true),
            ],
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 12),
          Text(
            summary,
            style: AeroText.body.copyWith(
              color: AeroColors.mist,
              fontSize: 15,
              shadows: const [Shadow(color: Color(0x99020D1C), blurRadius: 6)],
            ),
            maxLines: overviewLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Rouge doux des épisodes en retard, lisible sur le bleu des panneaux.
const Color _lateRed = Color(0xFFFF6B6B);

/// Prochains épisodes annoncés, avec leur date de première diffusion. Les
/// épisodes déjà diffusés que la playlist n'a pas encore passent devant, avec
/// la mention « Retard sur l'IPTV ».
class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({
    required this.episodes,
    this.late = const [],
    super.key,
  });

  final List<UpcomingEpisode> episodes;
  final List<UpcomingEpisode> late;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final performance = AeroLook.of(context).isPerformance;
    final shown = [
      for (final episode in late) (episode, true),
      for (final episode in episodes) (episode, false),
    ].take(_shownUpcoming).toList();
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.detailUpcoming,
            style: AeroText.body.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: CustomMultiChildLayout(
                delegate: _WholeItems(shown.length, gap: 8),
                children: [
                  for (final (index, (episode, isLate)) in shown.indexed)
                    LayoutId(
                      id: index,
                      child: _upcomingItem(
                        l10n,
                        episode,
                        isLate: isLate,
                        performance: performance,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.detailUpcomingNote,
            style: AeroText.caption.copyWith(
              fontSize: 12,
              color: AeroColors.mist,
              shadows: const [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _upcomingItem(
    AppLocalizations l10n,
    UpcomingEpisode episode, {
    required bool isLate,
    required bool performance,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: performance ? const Color(0xFF0A2443) : const Color(0x40010A18),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: isLate
            ? Border.all(color: const Color(0x99FF6B6B), width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              airDateLabel(l10n, episode.airDate),
              style: AeroText.caption.copyWith(
                color: AeroColors.aqua,
                shadows: const [],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.detailUpcomingEpisode(
                episode.season,
                episode.number,
                episode.title ?? l10n.detailUntitled,
              ),
              style: AeroText.body.copyWith(shadows: const []),
              maxLines: isLate ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isLate) ...[
              const SizedBox(height: 2),
              Text(
                l10n.detailLate,
                style: AeroText.caption.copyWith(
                  color: _lateRed,
                  fontWeight: FontWeight.w700,
                  shadows: const [],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empile les épisodes du haut vers le bas et cache ceux qui ne tiennent pas
/// en entier : sur un petit écran, mieux vaut un épisode de moins qu'un
/// épisode coupé.
final class _WholeItems extends MultiChildLayoutDelegate {
  _WholeItems(this.count, {required this.gap});

  final int count;
  final double gap;

  @override
  void performLayout(Size size) {
    var top = 0.0;
    var full = false;
    for (var index = 0; index < count; index++) {
      final child = layoutChild(
        index,
        BoxConstraints.tightFor(width: size.width),
      );
      full = full || top + child.height > size.height;
      // Hors du cadre, que ClipRect ne montre pas.
      positionChild(index, Offset(0, full ? size.height : top));
      top += child.height + gap;
    }
  }

  @override
  bool shouldRelayout(_WholeItems oldDelegate) =>
      oldDelegate.count != count || oldDelegate.gap != gap;
}
