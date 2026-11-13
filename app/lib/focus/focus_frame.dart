import 'package:flutter/widgets.dart';

import '../design_system/tokens/aero_look.dart';
import '../design_system/tokens/aero_tokens.dart';

const double _haloOutset = 16;
const Rect _haloSlice = Rect.fromLTRB(32, 32, 64, 64);

/// Taille minimale du halo : ses quatre coins doivent y tenir, avec un centre.
const double _haloMinimum = 66;
const Duration _scaleDuration = Duration(milliseconds: 110);

/// Forme du halo : celle de l'élément qu'il entoure.
enum HaloShape {
  card(AeroAssets.focusHalo),
  pill(AeroAssets.focusPill);

  const HaloShape(this.asset);

  final String asset;
}

/// Indicateur de focus commun à tous les éléments sélectionnables.
///
/// Le halo est une image pré-rendue et non une ombre : il ne coûte qu'un dessin
/// en plus, et reste identique sur chaque composant.
class FocusFrame extends StatelessWidget {
  const FocusFrame({
    required this.focused,
    required this.child,
    this.scale = 1.05,
    this.halo = HaloShape.card,
    super.key,
  });

  final bool focused;
  final Widget child;

  /// Agrandissement de l'élément actif.
  final double scale;
  final HaloShape halo;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: focused ? scale : 1,
      duration: animate ? _scaleDuration : Duration.zero,
      curve: Curves.easeOut,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          child,
          if (focused)
            Positioned(
              left: -_haloOutset,
              top: -_haloOutset,
              right: -_haloOutset,
              bottom: -_haloOutset,
              child: IgnorePointer(child: _Halo(shape: halo)),
            ),
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.shape});

  final HaloShape shape;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Mode Performance : un trait net, sans lueur à mélanger à l'image.
      if (AeroLook.of(context).isPerformance) {
        return Padding(
          padding: const EdgeInsets.all(_haloOutset - 5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: AeroColors.leaf, width: 3),
              borderRadius: BorderRadius.all(
                Radius.circular(shape == HaloShape.pill ? 32 : 16),
              ),
            ),
          ),
        );
      }
      if (constraints.maxWidth < _haloMinimum ||
          constraints.maxHeight < _haloMinimum) {
        // Trop petit pour la texture : une bordure garde le focus visible.
        return const Padding(
          padding: EdgeInsets.all(_haloOutset - 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: AeroColors.aqua, width: 2),
              ),
            ),
          ),
        );
      }
      return Image.asset(
        shape.asset,
        scale: AeroAssets.scale,
        centerSlice: _haloSlice,
        fit: BoxFit.fill,
      );
    },
  );
}
