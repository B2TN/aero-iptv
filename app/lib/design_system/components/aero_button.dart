import 'package:flutter/widgets.dart';

import '../../focus/focus_frame.dart';
import '../../focus/focusable.dart';
import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';

const double _minWidth = 64;
const double _minHeight = 46;

/// Couleur du bouton : le vert est réservé à l'action de lecture.
enum AeroTone { blue, green }

/// Relief doux du mode Aero : un dégradé, un liseré clair et une ombre portée.
BoxDecoration _aeroPill(AeroTone tone, {required bool focused}) =>
    switch (tone) {
      AeroTone.green => BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDFFFE9), Color(0xFF7FEAA6), Color(0xFF3FBF78)],
        ),
        border: Border.all(color: const Color(0xCCFFFFFF)),
        boxShadow: [
          BoxShadow(
            color: focused ? const Color(0x998CF5B4) : const Color(0x66010A18),
            blurRadius: focused ? 22 : 12,
            offset: focused ? Offset.zero : const Offset(0, 5),
          ),
        ],
      ),
      AeroTone.blue => BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: focused
              ? const [Color(0xCC5AA6E6), Color(0xCC1E5C99)]
              : const [Color(0x99408CD2), Color(0x9914467D)],
        ),
        border: Border.all(color: const Color(0x66EAF8FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59010A18),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
    };

/// Aplat du mode Performance : aucune ombre ni dégradé à calculer.
BoxDecoration _flatPill(AeroTone tone) => BoxDecoration(
  borderRadius: const BorderRadius.all(Radius.circular(28)),
  color: tone == AeroTone.green
      ? PerformanceColors.play
      : PerformanceColors.button,
  border: tone == AeroTone.green
      ? null
      : Border.all(color: PerformanceColors.buttonBorder),
);

/// Bouton en relief doux, qui s'illumine quand il a le focus.
class AeroButton extends StatelessWidget {
  const AeroButton({
    required this.label,
    required this.onSelect,
    this.icon,
    this.image,
    this.tone = AeroTone.blue,
    this.minWidth = _minWidth,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    super.key,
  });

  final String label;
  final IconData? icon;

  /// Icône pré-rendue, à la place de [icon].
  final String? image;
  final AeroTone tone;
  final double minWidth;
  final VoidCallback? onSelect;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context) {
    final asset = image;
    final performance = AeroLook.of(context).isPerformance;
    // Le vert est clair : le texte y passe en bleu nuit pour rester lisible.
    final ink = tone == AeroTone.green ? AeroColors.abyss : AeroColors.foam;
    return Focusable(
      onSelect: onSelect,
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      halo: HaloShape.pill,
      builder: (context, focused) => ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, minHeight: _minHeight),
        child: DecoratedBox(
          decoration: performance
              ? _flatPill(tone)
              : _aeroPill(tone, focused: focused),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (asset != null)
                  Image.asset(asset, width: 28, height: 28)
                else if (icon != null)
                  Icon(icon, color: ink, size: 20),
                if ((asset != null || icon != null) && label.isNotEmpty)
                  const SizedBox(width: 10),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: AeroText.body.copyWith(
                      color: ink,
                      fontWeight: tone == AeroTone.green
                          ? FontWeight.w600
                          : null,
                      shadows: const [],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
