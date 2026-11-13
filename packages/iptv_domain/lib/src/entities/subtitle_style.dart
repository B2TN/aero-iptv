/// Taille du texte des sous-titres.
enum SubtitleSize { small, medium, large, extraLarge }

/// Police des sous-titres. Seules des polices présentes sur tous les appareils
/// sont proposées.
enum SubtitleFont { standard, bold, serif, monospace }

/// Couleur du texte des sous-titres.
enum SubtitleColor { white, yellow, cyan, green }

/// Ce qui détache le texte de l'image.
enum SubtitleEdge { none, outline, shadow }

/// Couleur du bandeau placé derrière le texte.
enum SubtitleBackground { none, black, grey, navy }

/// Hauteur des sous-titres à l'écran.
enum SubtitlePosition { bottom, raised, higher, top }

/// Apparence des sous-titres, réglée dans les paramètres.
///
/// Les valeurs par défaut reproduisent l'apparence d'origine : texte blanc
/// cerné de noir, sans bandeau, en bas de l'image.
final class SubtitleStyle {
  const SubtitleStyle({
    this.size = SubtitleSize.medium,
    this.font = SubtitleFont.standard,
    this.color = SubtitleColor.white,
    this.edge = SubtitleEdge.outline,
    this.background = SubtitleBackground.none,
    this.backgroundOpacity = 50,
    this.position = SubtitlePosition.bottom,
  });

  /// Opacités proposées pour le bandeau, en pourcentage.
  static const List<int> opacities = [25, 50, 75, 100];

  final SubtitleSize size;
  final SubtitleFont font;
  final SubtitleColor color;
  final SubtitleEdge edge;
  final SubtitleBackground background;

  /// Opacité du bandeau, en pourcentage. Sans effet sans bandeau.
  final int backgroundOpacity;
  final SubtitlePosition position;

  SubtitleStyle copyWith({
    SubtitleSize? size,
    SubtitleFont? font,
    SubtitleColor? color,
    SubtitleEdge? edge,
    SubtitleBackground? background,
    int? backgroundOpacity,
    SubtitlePosition? position,
  }) => SubtitleStyle(
    size: size ?? this.size,
    font: font ?? this.font,
    color: color ?? this.color,
    edge: edge ?? this.edge,
    background: background ?? this.background,
    backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
    position: position ?? this.position,
  );

  @override
  bool operator ==(Object other) =>
      other is SubtitleStyle &&
      other.size == size &&
      other.font == font &&
      other.color == color &&
      other.edge == edge &&
      other.background == background &&
      other.backgroundOpacity == backgroundOpacity &&
      other.position == position;

  @override
  int get hashCode => Object.hash(
    size,
    font,
    color,
    edge,
    background,
    backgroundOpacity,
    position,
  );
}
