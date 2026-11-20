import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../../app/app_state.dart';
import '../../../design_system/components/aero_button.dart';
import '../../../design_system/components/aero_menu.dart';
import '../../../design_system/components/art_backdrop.dart';
import '../../../design_system/components/meta_tag.dart';
import '../../../design_system/glass/glass_panel.dart';
import '../../../design_system/tokens/aero_tokens.dart';

/// Hauteur du grand visuel, barre de navigation comprise : la première rangée
/// tient en entier dessous.
const double heroHeight = 428;

const double _playWidth = 168;
const double _infoWidth = 132;

/// Largeur du texte : l'image occupe le reste.
const double _textWidth = 540;

/// Grand visuel de l'accueil, en plein cadre : l'image du titre se fond dans
/// l'aurore, le texte et les boutons se posent à côté.
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
    final poster = item.movie?.posterUrl ?? item.series?.posterUrl;
    final url = item.imageUrl;
    // Sans image large, le visuel retombe sur l'affiche de la playlist.
    final wide = url != null && url != poster ? url : null;
    final year = item.movie?.year ?? item.series?.year;
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        // Le voile du texte déborde un peu sous le visuel, où il s'éteint.
        clipBehavior: Clip.none,
        children: [
          ArtBackdrop(
            key: ValueKey(_index),
            imageUrls: [?wide],
            posterUrl: poster,
            posterHeight: 290,
          ),
          // Le texte reste lisible même devant la lumière : un voile en
          // ellipse autour de lui, qui s'éteint avant ses bords, sans trait.
          const PositionedDirectional(
            start: -120,
            top: 40,
            width: 900,
            height: heroHeight + 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color(0x8C021229),
                      Color(0x59021229),
                      Color(0x00021229),
                    ],
                    stops: [0, 0.55, 1],
                    transform: _Stretch(),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: AeroMetrics.rowGutter,
            bottom: 18,
            width: _textWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AeroText.display,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (year != null) ...[
                  const SizedBox(height: 10),
                  MetaTag(text: '$year'),
                ],
                if (overview != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    overview,
                    style: AeroText.body.copyWith(
                      color: AeroColors.mist,
                      fontSize: 15,
                      shadows: const [
                        Shadow(color: Color(0x99020D1C), blurRadius: 6),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
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
                    const SizedBox(width: 14),
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
                    if (widget.items.length > 1) ...[
                      const SizedBox(width: 24),
                      _PageDots(count: widget.items.length, index: _index),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Étire un dégradé circulaire en ellipse, à la taille de sa boîte.
class _Stretch extends GradientTransform {
  const _Stretch();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final center = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(
        bounds.width / bounds.shortestSide,
        bounds.height / bounds.shortestSide,
        1,
        1,
      )
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
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

/// Position dans le carrousel : le titre affiché est un trait allongé.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < count; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              color: i == index ? AeroColors.foam : const Color(0x66D3E6F6),
            ),
          ),
        ),
    ],
  );
}
