import 'package:flutter/widgets.dart';

import '../tokens/aero_look.dart';
import '../tokens/aero_tokens.dart';

/// Petite étiquette de verre : année, genre, durée. [accent] la met en avant,
/// en vert, comme « En cours de diffusion ».
class MetaTag extends StatelessWidget {
  const MetaTag({required this.text, this.accent = false, super.key});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final performance = AeroLook.of(context).isPerformance;
    final Color fill;
    final Color edge;
    if (accent) {
      fill = performance ? const Color(0xFF24552F) : const Color(0x339BEA7C);
      edge = performance ? const Color(0xFF4F9A4A) : const Color(0x809BEA7C);
    } else {
      fill = performance ? PerformanceColors.button : const Color(0x24FFFFFF);
      edge = performance
          ? PerformanceColors.buttonBorder
          : const Color(0x40FFFFFF);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: edge),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: Text(
            text,
            style: AeroText.caption.copyWith(
              color: accent ? const Color(0xFFDDFFCF) : AeroColors.foam,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
