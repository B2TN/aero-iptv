import 'package:flutter/widgets.dart';

import '../../focus/focus_frame.dart';
import '../../focus/focusable.dart';
import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';

const double _minWidth = 64;
const double _minHeight = 46;

/// Couleur du bouton : le vert est réservé à l'action de lecture.
enum AeroTone { blue, green }

const BorderRadius _pill = BorderRadius.all(Radius.circular(28));

/// Gel vert de la lecture : un dégradé d'herbe, un reflet en haut, et une
/// lueur quand il a le focus.
BoxDecoration _gel({required bool focused}) => BoxDecoration(
  borderRadius: _pill,
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF2FFE6),
      Color(0xFFB4F296),
      Color(0xFF7ED65C),
      Color(0xFF4FB33B),
    ],
    stops: [0, 0.45, 0.55, 1],
  ),
  border: Border.all(color: const Color(0xD9FFFFFF)),
  boxShadow: [
    BoxShadow(
      color: focused ? const Color(0xA69BEA7C) : const Color(0x59010A18),
      blurRadius: focused ? 26 : 12,
      offset: focused ? Offset.zero : const Offset(0, 5),
    ),
  ],
);

/// Verre clair des autres boutons. Avec le focus, il devient blanc, avec un
/// texte sombre : il se repère de loin, comme la carte active.
BoxDecoration _glass({required bool focused}) => focused
    ? const BoxDecoration(
        borderRadius: _pill,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFDCF1FF)],
        ),
        boxShadow: [BoxShadow(color: Color(0x808ADCFF), blurRadius: 22)],
      )
    : const BoxDecoration(
        borderRadius: _pill,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x47FFFFFF), Color(0x1FFFFFFF)],
        ),
        border: Border.fromBorderSide(BorderSide(color: Color(0x59FFFFFF))),
      );

/// Aplat du mode Performance : aucune ombre ni dégradé à calculer.
BoxDecoration _flatPill(AeroTone tone, {required bool focused}) =>
    switch (tone) {
      AeroTone.green => const BoxDecoration(
        borderRadius: _pill,
        color: PerformanceColors.play,
      ),
      AeroTone.blue => BoxDecoration(
        borderRadius: _pill,
        color: focused ? AeroColors.foam : PerformanceColors.button,
        border: focused
            ? null
            : Border.all(color: PerformanceColors.buttonBorder),
      ),
    };

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
    return Focusable(
      onSelect: onSelect,
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      halo: HaloShape.pill,
      builder: (context, focused) {
        // Sur le vert et sur le blanc du focus, le texte passe en bleu nuit.
        final ink = tone == AeroTone.green || focused
            ? AeroColors.abyss
            : AeroColors.foam;
        return ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            minHeight: _minHeight,
          ),
          child: DecoratedBox(
            decoration: performance
                ? _flatPill(tone, focused: focused)
                : tone == AeroTone.green
                ? _gel(focused: focused)
                : _glass(focused: focused),
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
                      style: AeroText.label.copyWith(
                        color: ink,
                        fontWeight: tone == AeroTone.green
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
