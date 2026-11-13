import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(20));

/// Flou du verre dépoli, en mode Aero seulement.
const double _blurSigma = 18;

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
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: _radius,
            border: Border.fromBorderSide(BorderSide(color: Color(0x42EAF8FF))),
            // Un liseré clair en haut, comme la lumière sur l'arête du verre.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x4DFFFFFF), Color(0x24EAF8FF), Color(0x0DEAF8FF)],
              stops: [0, 0.03, 1],
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
