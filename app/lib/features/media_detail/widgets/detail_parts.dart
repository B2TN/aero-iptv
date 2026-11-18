import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
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

/// Titre d'une fiche, ses étiquettes et son résumé.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    required this.title,
    required this.tags,
    this.highlight,
    this.overview,
    super.key,
  });

  final String title;

  /// Année, genre, durée ou nombre de saisons.
  final List<String> tags;

  /// Étiquette mise en avant, comme « En cours de diffusion ».
  final String? highlight;
  final String? overview;

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
          style: AeroText.display.copyWith(fontSize: 40),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (tags.isNotEmpty || accent != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final tag in tags) _Tag(text: tag),
              if (accent != null) _Tag(text: accent, accent: true),
            ],
          ),
        ],
        if (summary != null) ...[
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text(
              summary,
              style: AeroText.body.copyWith(
                color: AeroColors.mist,
                height: 1.45,
                shadows: const [],
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    final Color fill;
    final Color edge;
    if (accent) {
      fill = performance ? const Color(0xFF1C5A45) : const Color(0x298CF5B4);
      edge = performance ? const Color(0xFF3E9C70) : const Color(0x668CF5B4);
    } else {
      fill = performance ? PerformanceColors.button : const Color(0x1FEAF8FF);
      edge = performance
          ? PerformanceColors.buttonBorder
          : const Color(0x38EAF8FF);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: edge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            text,
            style: AeroText.caption.copyWith(
              color: accent ? const Color(0xFFCFFFE0) : AeroColors.foam,
              shadows: const [],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
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
