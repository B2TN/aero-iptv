import 'dart:async';
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

/// Écran complet : l'aurore du fond, puis le canevas.
class AeroCanvas extends StatelessWidget {
  const AeroCanvas({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Couche isolée : le fond n'est jamais redessiné quand le focus bouge.
      const RepaintBoundary(child: AeroSky()),
      AeroScale(child: child),
    ],
  );
}

/// Aurore du fond : un bleu profond, une grande lumière en haut à droite et des
/// rubans de lumière, plus sombre vers le bas. En mode Aero, des points de
/// lumière dérivent lentement et la grande lumière respire ; en mode
/// Performance, l'image reste immobile, décodée en plus petit.
class AeroSky extends StatelessWidget {
  const AeroSky({super.key});

  /// Largeur de décodage du mode Performance : l'aurore est douce, elle
  /// supporte d'être agrandie, et pèse quatre fois moins en mémoire.
  static const int _performanceWidth = 960;

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    final sky = Image(
      image: ResizeImage.resizeIfNeeded(
        performance ? _performanceWidth : null,
        null,
        const AssetImage(AeroAssets.background),
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
    if (performance) return sky;
    return Stack(
      fit: StackFit.expand,
      children: [
        sky,
        _Motion(still: MediaQuery.disableAnimationsOf(context)),
      ],
    );
  }
}

/// Une boucle complète des points de lumière, en secondes : un défilement que
/// l'on remarque à peine.
const double _loopSeconds = 420;

/// Respiration de la grande lumière, en secondes.
const double _breathSeconds = 14;

/// Cadence des mouvements : bien plus lente que l'écran. Chaque pas redessine
/// l'écran, et les points vont si lentement que l'œil n'y voit pas de saccade.
const Duration _step = Duration(milliseconds: 66);

/// Points de lumière qui dérivent et grande lumière qui respire. Ils
/// s'arrêtent quand l'écran est caché, par exemple sous le lecteur, ou quand
/// l'application passe en arrière-plan.
class _Motion extends StatefulWidget {
  const _Motion({required this.still});

  /// Vrai quand le système demande moins d'animations.
  final bool still;

  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> {
  /// Horloge commune à tous les écrans : une fiche ouverte montre les points
  /// de lumière là où l'accueil les laissait.
  static final Stopwatch _clock = Stopwatch()..start();

  /// Temps de l'horloge, en secondes, partagé par les deux mouvements.
  final ValueNotifier<double> _time = ValueNotifier(_seconds);
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        _update();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    _update();
  }

  @override
  void didUpdateWidget(_Motion oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    final moving = _visible && _foreground && !widget.still;
    if (moving && _timer == null) {
      _timer = Timer.periodic(_step, (_) => _time.value = _seconds);
    } else if (!moving && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  static double get _seconds => _clock.elapsedMilliseconds / 1000;

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = height * AeroAssets.motesBand.aspectRatio;
        final tiles = (constraints.maxWidth / width).ceil() + 1;
        return Stack(
          fit: StackFit.expand,
          children: [
            // La lueur ne change que d'opacité : l'écran ne fait que la
            // mélanger à nouveau, sans la redessiner.
            ValueListenableBuilder<double>(
              valueListenable: _time,
              builder: (context, time, glow) => Opacity(
                opacity:
                    0.55 + 0.45 * math.sin(time / _breathSeconds * 2 * math.pi),
                child: glow,
              ),
              child: const RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.5, -0.69),
                      radius: 0.7,
                      colors: [Color(0x4DBFEFFF), Color(0x00BFEFFF)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _time,
                    builder: (context, time, band) => Transform.translate(
                      offset: Offset(-(time / _loopSeconds % 1) * width, 0),
                      child: band,
                    ),
                    child: RepaintBoundary(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < tiles; i++)
                            Image(
                              image: const AssetImage(AeroAssets.motes),
                              width: width,
                              height: height,
                              fit: BoxFit.fill,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.low,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
