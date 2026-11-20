import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

/// Pastille de la ligne active : du blanc, comme les boutons qui ont le focus.
const BoxDecoration _focusedAero = BoxDecoration(
  borderRadius: _radius,
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFDCF1FF)],
  ),
);
const BoxDecoration _focusedFlat = BoxDecoration(
  borderRadius: _radius,
  color: AeroColors.foam,
);

/// Ligne déjà choisie, comme la saison affichée : un verre à peine visible.
const BoxDecoration _selected = BoxDecoration(
  borderRadius: _radius,
  color: Color(0x1FFFFFFF),
);

/// Ligne d'une liste au D-pad. Avec le focus, elle devient une pastille
/// blanche au texte sombre, lisible de loin ; la ligne choisie garde un
/// voile léger.
class FocusRow extends StatelessWidget {
  const FocusRow({
    required this.focused,
    required this.child,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    super.key,
  });

  final bool focused;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: focused
        ? AeroLook.of(context).isPerformance
              ? _focusedFlat
              : _focusedAero
        : selected
        ? _selected
        : const BoxDecoration(),
    child: Padding(padding: padding, child: child),
  );
}

/// Couleur du texte d'une ligne : sombre sur la pastille du focus, cyan pour
/// la ligne choisie ou en cours.
Color rowInk({required bool focused, bool selected = false}) => focused
    ? AeroColors.abyss
    : selected
    ? AeroColors.aqua
    : AeroColors.foam;

/// Couleur du texte secondaire d'une ligne.
Color rowSubtleInk({required bool focused}) =>
    focused ? const Color(0xB303152B) : AeroColors.mist;
