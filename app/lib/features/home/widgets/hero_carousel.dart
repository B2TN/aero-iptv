import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/poster_image.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';

const double _heroHeight = 226;
const double _playWidth = 168;
const double _infoWidth = 132;
const double _frameRadius = 14;
const Rect _frameSlice = Rect.fromLTRB(20, 20, 44, 44);

/// Une affiche se décode à la hauteur du cadre, une image large à sa largeur.
const int _posterDecodeWidth = 320;
const int _backdropDecodeWidth = 960;

/// Décodée si petite, l'image agrandie devient un fond flou, sans aucun filtre.
const int _ambientDecodeWidth = 32;

/// Grand visuel de l'accueil, présenté derrière une vitre.
///
/// Le carrousel n'avance pas seul, pour ne pas décoder d'image tant que personne
/// ne regarde. Gauche sur Lecture et droite sur Informations changent de titre.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({required this.items, required this.onOpen, super.key});

  final List<HeroItem> items;
  final ValueChanged<HeroItem> onOpen;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final FocusNode _actionNode = FocusNode(debugLabel: 'HeroAction');
  int _index = 0;

  HeroItem get _item => widget.items[_index.clamp(0, widget.items.length - 1)];

  @override
  void initState() {
    super.initState();
    // L'accueil arrive après un chargement : `autofocus` ne suffit pas, car le
    // focus est déjà posé sur la barre supérieure à ce moment-là.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) {
        _actionNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _actionNode.dispose();
    super.dispose();
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  KeyEventResult _onPlayKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _index == 0) return KeyEventResult.ignored;
    final previous = _isRtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;
    if (event.logicalKey != previous) return KeyEventResult.ignored;
    setState(() => _index--);
    return KeyEventResult.handled;
  }

  KeyEventResult _onInfoKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _index >= widget.items.length - 1) {
      return KeyEventResult.ignored;
    }
    final next = _isRtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    if (event.logicalKey != next) return KeyEventResult.ignored;
    setState(() => _index++);
    return KeyEventResult.handled;
  }

  Future<void> _showInfo(HeroItem item) => showAeroOverlay<void>(
    context,
    label: context.l10n.homeInfo,
    builder: (context) => _InfoSheet(item: item),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = _item;
    final overview = item.overview;
    return SizedBox(
      height: _heroHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AeroMetrics.rowGutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 11,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AeroText.display,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (overview != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      overview,
                      style: AeroText.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: _onPlayKey,
                        child: AeroButton(
                          label: item.movie != null
                              ? l10n.homePlay
                              : l10n.homeOpen,
                          icon: item.movie != null
                              ? Icons.play_arrow_rounded
                              : Icons.video_library_rounded,
                          tone: AeroTone.green,
                          minWidth: _playWidth,
                          focusNode: _actionNode,
                          onSelect: () => widget.onOpen(item),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: _onInfoKey,
                        child: AeroButton(
                          label: l10n.homeInfo,
                          icon: Icons.info_outline_rounded,
                          minWidth: _infoWidth,
                          onSelect: () => _showInfo(item),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            const SizedBox(width: 36),
            Expanded(
              flex: 13,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: _Visual(
                  item: item,
                  index: _index,
                  count: widget.items.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texte complet du titre, ouvert par le bouton d'information.
class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.item});

  final HeroItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SizedBox(
        width: 640,
        child: GlassPanel(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AeroText.title),
              const SizedBox(height: 12),
              Text(
                item.overview ?? l10n.homeNoOverview,
                style: AeroText.body,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 22),
              AeroButton(
                label: l10n.actionBack,
                autofocus: true,
                onSelect: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Visual extends StatelessWidget {
  const _Visual({required this.item, required this.index, required this.count});

  final HeroItem item;
  final int index;
  final int count;

  /// Sans image large, le visuel retombe sur l'affiche de la playlist.
  bool get _isPoster {
    final url = item.imageUrl;
    return url == item.movie?.posterUrl || url == item.series?.posterUrl;
  }

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final poster = _isPoster;
    // Couche isolée : changer le focus ne redessine pas le visuel.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(_frameRadius)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF0A2C4E)),
                if (poster) ...[
                  PosterImage(
                    url: url,
                    decodeWidth: _ambientDecodeWidth,
                    placeholder: const SizedBox.shrink(),
                  ),
                  const ColoredBox(color: Color(0x7304142B)),
                ],
                PosterImage(
                  url: url,
                  decodeWidth: poster
                      ? _posterDecodeWidth
                      : _backdropDecodeWidth,
                  fit: poster ? BoxFit.contain : BoxFit.cover,
                  placeholder: const SizedBox.shrink(),
                ),
                const Image(
                  image: AssetImage(AeroAssets.heroGloss),
                  fit: BoxFit.fill,
                ),
              ],
            ),
          ),
          Image.asset(
            AeroAssets.heroFrame,
            centerSlice: _frameSlice,
            scale: AeroAssets.scale,
            fit: BoxFit.fill,
          ),
          const _Flare(alignment: Alignment.topCenter),
          const _Flare(alignment: Alignment.bottomCenter),
          if (count > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: _PageDots(count: count, index: index),
            ),
        ],
      ),
    );
  }
}

/// Trait de lumière sur l'arête de la vitre.
class _Flare extends StatelessWidget {
  const _Flare({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: FractionalTranslation(
      translation: Offset(0, alignment.y / 2),
      child: const FractionallySizedBox(
        widthFactor: 0.62,
        child: Image(
          image: AssetImage(AeroAssets.edgeFlare),
          height: 12,
          fit: BoxFit.fill,
        ),
      ),
    ),
  );
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: SizedBox(
            width: 7,
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? AeroColors.aqua : AeroColors.mist,
              ),
            ),
          ),
        ),
    ],
  );
}
