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

final _seasonsProvider = FutureProvider.autoDispose
    .family<List<Season>, ({int sourceId, int entryId})>(
      (ref, key) => ref
          .watch(catalogRepositoryProvider)
          .seasonsOf(key.sourceId, key.entryId),
    );

/// Saisons et épisodes d'une version de série.
class MediaDetailScreen extends ConsumerStatefulWidget {
  const MediaDetailScreen({
    required this.sourceId,
    required this.series,
    required this.seriesEntryId,
    super.key,
  });

  final int sourceId;
  final Series series;
  final int seriesEntryId;

  @override
  ConsumerState<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends ConsumerState<MediaDetailScreen> {
  final FocusNode _backNode = FocusNode(debugLabel: 'DetailBack');
  int _season = 0;

  @override
  void dispose() {
    _backNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seasons = ref.watch(
      _seasonsProvider((
        sourceId: widget.sourceId,
        entryId: widget.seriesEntryId,
      )),
    );
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
                    const SizedBox(height: 16),
                    Text(
                      widget.series.title,
                      style: AeroText.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: seasons.when(
                  loading: () => AeroLoading(label: l10n.loading),
                  error: (error, _) => AeroMessage(
                    title: l10n.loadErrorTitle,
                    actionLabel: l10n.actionBack,
                    onAction: () => Navigator.of(context).maybePop(),
                  ),
                  data: _buildSeasons,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasons(List<Season> seasons) {
    final l10n = context.l10n;
    if (seasons.isEmpty) {
      return AeroMessage(title: l10n.detailNoEpisodes, autofocus: false);
    }
    final season = seasons[_season.clamp(0, seasons.length - 1)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: GlassPanel(
            padding: const EdgeInsets.all(12),
            child: DpadCollection.vertical(
              itemCount: seasons.length,
              itemExtent: 48,
              padding: const EdgeInsets.all(4),
              onIndexChanged: (index) => setState(() => _season = index),
              onSelect: (index) => setState(() => _season = index),
              itemBuilder: (context, index, focused) => _Line(
                text: l10n.detailSeason(seasons[index].number),
                focused: focused,
                selected: index == _season,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: GlassPanel(
            padding: const EdgeInsets.all(12),
            child: DpadCollection.vertical(
              key: ValueKey(season.number),
              autofocus: true,
              itemCount: season.episodes.length,
              itemExtent: 56,
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
                return _Line(
                  text: episode.title == widget.series.title
                      ? label
                      : '$label : ${episode.title}',
                  focused: focused,
                );
              },
            ),
          ),
        ),
      ],
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
