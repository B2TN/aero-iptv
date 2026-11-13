import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:iptv_domain/iptv_domain.dart';

/// Taille du texte, sur le canevas de 1280 × 720.
const Map<SubtitleSize, double> _fontSizes = {
  SubtitleSize.small: 22,
  SubtitleSize.medium: 28,
  SubtitleSize.large: 34,
  SubtitleSize.extraLarge: 42,
};

const Map<SubtitleColor, Color> _textColors = {
  SubtitleColor.white: Color(0xFFFFFFFF),
  SubtitleColor.yellow: Color(0xFFFFF06A),
  SubtitleColor.cyan: Color(0xFF7FE3FF),
  SubtitleColor.green: Color(0xFF8CF5B4),
};

const Map<SubtitleBackground, Color> _backgroundColors = {
  SubtitleBackground.black: Color(0xFF000000),
  SubtitleBackground.grey: Color(0xFF3C3C3C),
  SubtitleBackground.navy: Color(0xFF04142B),
};

/// Écart entre le bas de l'image et le texte, selon sa position.
const Map<SubtitlePosition, double> _bottomGaps = {
  SubtitlePosition.bottom: 44,
  SubtitlePosition.raised: 110,
  SubtitlePosition.higher: 180,
};

/// Écart minimal quand les commandes du lecteur occupent le bas de l'image.
const double _aboveControls = 236;
const double _topGap = 60;

/// Le contour remplace une ombre floue, coûteuse à dessiner sur un stick à
/// chaque changement de texte.
const List<Shadow> _outline = [
  Shadow(color: Color(0xFF000000), offset: Offset(1.5, 1.5)),
  Shadow(color: Color(0xFF000000), offset: Offset(-1.5, 1.5)),
  Shadow(color: Color(0xFF000000), offset: Offset(1.5, -1.5)),
  Shadow(color: Color(0xFF000000), offset: Offset(-1.5, -1.5)),
];

/// Une seule ombre, légèrement floue.
const List<Shadow> _dropShadow = [
  Shadow(color: Color(0xE6000000), offset: Offset(2, 2), blurRadius: 3),
];

/// Style du texte des sous-titres.
TextStyle subtitleTextStyle(SubtitleStyle style) => TextStyle(
  color: _textColors[style.color],
  fontSize: _fontSizes[style.size],
  fontWeight: style.font == SubtitleFont.bold
      ? FontWeight.w700
      : FontWeight.w500,
  fontFamily: switch (style.font) {
    SubtitleFont.serif => 'serif',
    SubtitleFont.monospace => 'monospace',
    SubtitleFont.standard || SubtitleFont.bold => null,
  },
  // Les noms génériques ne valent que sur Android : Windows prend ces polices.
  fontFamilyFallback: switch (style.font) {
    SubtitleFont.serif => const ['Georgia', 'Times New Roman', 'Noto Serif'],
    SubtitleFont.monospace => const ['Consolas', 'Courier New', 'Noto Mono'],
    SubtitleFont.standard || SubtitleFont.bold => null,
  },
  height: 1.25,
  shadows: switch (style.edge) {
    SubtitleEdge.none => null,
    SubtitleEdge.outline => _outline,
    SubtitleEdge.shadow => _dropShadow,
  },
);

/// Couleur du bandeau, ou `null` sans bandeau.
Color? subtitleBackgroundColor(SubtitleStyle style) {
  final color = _backgroundColors[style.background];
  return color?.withValues(alpha: style.backgroundOpacity / 100);
}

/// Réplique placée sur l'image, selon les réglages d'apparence.
///
/// Le lecteur et l'aperçu des paramètres l'affichent de la même façon.
class SubtitleLayer extends StatelessWidget {
  const SubtitleLayer({
    required this.text,
    required this.style,
    this.raised = false,
    super.key,
  });

  /// Texte affiché. Vide entre deux répliques.
  final ValueListenable<String> text;
  final SubtitleStyle style;

  /// Les commandes du lecteur sont affichées : le texte passe au-dessus.
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final top = style.position == SubtitlePosition.top;
    final gap = _bottomGaps[style.position] ?? 0;
    final textStyle = subtitleTextStyle(style);
    final background = subtitleBackgroundColor(style);
    return IgnorePointer(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: top
              ? const EdgeInsets.fromLTRB(80, _topGap, 80, 0)
              : EdgeInsets.fromLTRB(
                  80,
                  0,
                  80,
                  raised && gap < _aboveControls ? _aboveControls : gap,
                ),
          child: ValueListenableBuilder<String>(
            valueListenable: text,
            builder: (context, line, _) {
              final label = Text(
                line,
                style: textStyle,
                textAlign: TextAlign.center,
              );
              if (background == null || line.isEmpty) return label;
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: label,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
