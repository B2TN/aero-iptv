import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';
import 'poster_image.dart';

/// Bleu de l'aurore à la hauteur où finit l'image, en mode Performance : le
/// voile du bas y aboutit, et l'image rejoint le fond sans trait.
const Color _performanceFade = Color(0xFF07305F);

/// Grande image d'un titre, fondue dans l'aurore : elle occupe la fin de la
/// ligne et s'efface vers son début, là où s'écrit le texte, et vers le bas, où
/// passent les rangées. Les rubans de lumière restent visibles autour.
///
/// La boîte reçue couvre toute la largeur : le masque part ainsi du bord de
/// l'écran, et le bord de l'image ne se voit nulle part.
///
/// Sans image large, l'affiche agrandie et très floue colore la place, et
/// l'affiche nette se pose par-dessus.
///
/// En mode Performance, l'image ne se fond pas dans l'aurore, ce qui demanderait
/// un masque calculé à chaque image : elle prend toute la largeur, sous deux
/// voiles sombres en dégradé.
class ArtBackdrop extends StatelessWidget {
  const ArtBackdrop({
    required this.imageUrl,
    this.posterUrl,
    this.decodeWidth = 1280,
    this.artShare = 0.78,
    this.textShare = 0.36,
    this.fadeFrom = 0.58,
    this.posterHeight = 300,
    this.posterAlignment = const AlignmentDirectional(0.62, -0.05),
    super.key,
  });

  /// Image large, au format 16:9.
  final String? imageUrl;

  /// À défaut d'image large, l'affiche.
  final String? posterUrl;
  final int decodeWidth;

  /// Part de la largeur occupée par l'image, du côté de la fin de la ligne.
  final double artShare;

  /// Part de l'image, côté début de ligne, sur laquelle elle s'efface.
  final double textShare;

  /// Hauteur, en part de la boîte, à partir de laquelle l'image s'efface vers
  /// le bas.
  final double fadeFrom;
  final double posterHeight;

  /// Place de l'affiche nette dans la part de l'image.
  final AlignmentGeometry posterAlignment;

  /// Décodée à cette taille puis agrandie, l'affiche devient un fond flou, sans
  /// aucun filtre à calculer.
  static const int _ambientWidth = 32;

  @override
  Widget build(BuildContext context) {
    final wide = imageUrl;
    final poster = posterUrl;
    if (wide == null && poster == null) return const SizedBox.shrink();
    final performance = AeroLook.of(context).isPerformance;
    final share = performance ? 1.0 : artShare;
    Widget region(Widget child) => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: share,
        heightFactor: 1,
        child: child,
      ),
    );
    final art = region(
      wide != null
          ? PosterImage(
              url: wide,
              decodeWidth: decodeWidth,
              alignment: Alignment.topCenter,
              placeholder: const SizedBox.shrink(),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                PosterImage(
                  url: poster,
                  decodeWidth: _ambientWidth,
                  placeholder: const SizedBox.shrink(),
                ),
                const ColoredBox(color: Color(0x6603152B)),
              ],
            ),
    );
    final sharp = wide == null
        ? region(
            Align(
              alignment: posterAlignment,
              child: _Poster(url: poster, height: posterHeight),
            ),
          )
        : null;
    if (performance) {
      return RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            art,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: const [Color(0xF207305F), Color(0x0007305F)],
                  stops: [textShare * 0.6, textShare + 0.3],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x0007305F), _performanceFade],
                  stops: [fadeFrom, 1],
                ),
              ),
            ),
            ?sharp,
          ],
        ),
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // L'image commence à `from` et devient opaque à `to`, en part de la boîte.
    final from = 1 - artShare;
    final to = from + (textShare + 0.24) * artShare;
    // Couche isolée : le focus qui bouge ne redessine pas l'image.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
              end: rtl ? Alignment.centerLeft : Alignment.centerRight,
              colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
              stops: [from, to],
            ).createShader(bounds),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                stops: [fadeFrom, 1],
              ).createShader(bounds),
              child: art,
            ),
          ),
          ?sharp,
        ],
      ),
    );
  }
}

/// Affiche nette, posée sur son fond flou, avec un liseré de verre.
class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.height});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * 2 / 3,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: Color(0x8C010A18),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(url: url, decodeWidth: (height * 4 / 3).round()),
            const Image(
              image: AssetImage(AeroAssets.cardFrame),
              fit: BoxFit.fill,
            ),
          ],
        ),
      ),
    ),
  );
}
