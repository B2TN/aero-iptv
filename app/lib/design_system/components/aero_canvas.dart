import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';

/// En dessous, les écrans n'ont plus la place de s'organiser : le canevas gagne
/// alors en hauteur plutôt que de rétrécir.
const double _minCanvasWidth = 1100;

/// Canevas d'au moins 720 unités de haut, mis à l'échelle de l'écran.
///
/// La mise en page est ainsi identique sur une TV et sur un PC, et la navigation
/// directionnelle se comporte partout de la même façon. Sur une TV, il mesure
/// 1280 × 720. Il prend toujours les proportions exactes de la fenêtre : quelle
/// que soit sa forme, l'interface occupe toute la place, sans bandes vides.
class AeroScale extends StatelessWidget {
  const AeroScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Une fenêtre réduite dans la barre des tâches mesure zéro.
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
        return const SizedBox.shrink();
      }
      final ratio = constraints.maxWidth / constraints.maxHeight;
      final width = math.max(
        _minCanvasWidth,
        AeroMetrics.canvas.height * ratio,
      );
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(width: width, height: width / ratio, child: child),
        ),
      );
    },
  );
}

/// Écran complet : fond sous-marin et canevas.
class AeroCanvas extends StatelessWidget {
  const AeroCanvas({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Couche isolée : le fond n'est jamais redessiné quand le focus bouge.
      RepaintBoundary(
        child: AeroLook.of(context).isPerformance
            // Un dégradé, sans image à décoder ni à garder en mémoire.
            ? const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PerformanceColors.backgroundTop,
                      PerformanceColors.backgroundMiddle,
                      PerformanceColors.backgroundBottom,
                    ],
                    stops: [0, 0.6, 1],
                  ),
                ),
              )
            : const Image(
                image: AssetImage(AeroAssets.background),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
              ),
      ),
      AeroScale(child: child),
    ],
  );
}
