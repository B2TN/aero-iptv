import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(18));

/// Flou du verre dépoli, en mode Aero seulement.
const double _blurSigma = 16;

/// Verre teinté de bleu nuit : le texte blanc s'y lit aussi bien devant le ciel
/// clair que devant les collines sombres. Le haut s'éclaire d'un liseré, comme
/// la lumière sur l'arête du verre.
const BoxDecoration _aeroGlass = BoxDecoration(
  borderRadius: _radius,
  border: Border.fromBorderSide(BorderSide(color: Color(0x40EAF8FF))),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x80C6E6FF),
      Color(0x8C2A5F9C),
      Color(0x8C0B2C55),
      Color(0x9E061C38),
    ],
    stops: [0, 0.02, 0.5, 1],
  ),
);

/// Panneau de verre.
///
/// En mode Aero, il floute ce qui passe derrière lui : c'est l'effet le plus
/// coûteux de l'interface. En mode Performance, il devient un aplat opaque,
/// sans flou ni reflet, que même un Fire TV Stick dessine sans effort.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    if (AeroLook.of(context).isPerformance) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: PerformanceColors.panel,
          borderRadius: _radius,
          border: Border.fromBorderSide(
            BorderSide(color: PerformanceColors.panelBorder),
          ),
        ),
        child: content,
      );
    }
    return ClipRRect(
      borderRadius: _radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: DecoratedBox(decoration: _aeroGlass, child: content),
      ),
    );
  }
}
