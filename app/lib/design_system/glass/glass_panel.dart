import 'package:flutter/widgets.dart';

import '../tokens/aero_tokens.dart';

const Rect _panelSlice = Rect.fromLTRB(24, 24, 40, 40);

/// Les coins de la texture occupent 48 unités : le centre doit garder une taille.
const double _minPanelSize = 50;

/// Panneau de verre : une image pré-rendue étirée en neuf zones.
///
/// Il n'utilise volontairement pas `BackdropFilter` : le flou en temps réel
/// ferait chuter les images par seconde sur un stick. L'aspect dépoli est déjà
/// contenu dans la texture.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(
      minWidth: _minPanelSize,
      minHeight: _minPanelSize,
    ),
    child: DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AeroAssets.glassPanel),
          centerSlice: _panelSlice,
          scale: AeroAssets.scale,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        ),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}
