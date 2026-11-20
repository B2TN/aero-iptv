import 'package:flutter/widgets.dart';

/// Palette Frutiger Aero : un bleu profond traversé de lumière, du verre clair,
/// et un vert d'herbe réservé à l'action principale.
abstract final class AeroColors {
  /// Bleu du ciel, couleur de la marque.
  static const Color lagoon = Color(0xFF1F6FC5);

  /// Cyan clair : valeurs, liens et lueurs.
  static const Color aqua = Color(0xFF8FE4FF);

  /// Texte principal.
  static const Color foam = Color(0xFFF4FAFF);

  /// Nuit du bas de l'écran, et encre sur le vert.
  static const Color abyss = Color(0xFF03152B);

  /// Vert d'herbe : l'élément actif et la lecture.
  static const Color leaf = Color(0xFF9BEA7C);

  /// Texte secondaire.
  static const Color mist = Color(0xD9D3E6F6);

  /// Voile posé sur l'écran sous une fenêtre.
  static const Color veil = Color(0xB803152B);
  static const Color progressStart = Color(0xFF7ADF5A);
  static const Color progressEnd = Color(0xFF3AA2F2);

  /// Fond des surfaces sombres, sous le texte : bas de l'aurore.
  static const Color night = Color(0xFF020D1C);
}

/// Textures générées par `tool/render_aero_textures_test.dart`.
abstract final class AeroAssets {
  /// Échelle des textures de l'interface.
  static const double scale = 2;

  /// Aurore du fond : rubans de lumière sur un bleu profond.
  static const String background = 'assets/aero/backgrounds/aurora.jpg';

  /// Points de lumière qui dérivent devant l'aurore, à demi-résolution.
  static const String motes = 'assets/aero/backgrounds/motes.png';
  static const Size motesBand = Size(2400, 1080);
  static const String focusHalo = 'assets/aero/focus/focus_halo.png';
  static const String focusPill = 'assets/aero/focus/focus_pill.png';
  static const String cardFrame = 'assets/aero/chrome/card_frame.png';
  static const String chevron = 'assets/aero/icons/chevron.png';
}

/// Échelle typographique : Inter pour le texte, sa coupe Display pour les
/// grands titres, et Noto Sans Arabic pour l'arabe.
abstract final class AeroText {
  static const String family = 'Inter';
  static const String displayFamily = 'InterDisplay';
  static const List<String> fallback = ['NotoSansArabic'];

  /// Lisibilité sur le ciel : une ombre douce sous les titres.
  static const List<Shadow> _lift = [
    Shadow(color: Color(0x8C020D1C), offset: Offset(0, 1), blurRadius: 6),
  ];

  /// Titre d'une fiche ou du grand visuel.
  static const TextStyle display = TextStyle(
    color: AeroColors.foam,
    fontFamily: displayFamily,
    fontFamilyFallback: fallback,
    fontSize: 46,
    fontWeight: FontWeight.w600,
    height: 1.06,
    letterSpacing: -0.6,
    shadows: _lift,
  );

  /// Titre d'une fenêtre ou d'un écran.
  static const TextStyle title = TextStyle(
    color: AeroColors.foam,
    fontFamily: displayFamily,
    fontFamilyFallback: fallback,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: -0.2,
    shadows: _lift,
  );

  /// Titre d'une rangée ou d'une section.
  static const TextStyle heading = TextStyle(
    color: AeroColors.foam,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.1,
    shadows: _lift,
  );
  static const TextStyle body = TextStyle(
    color: AeroColors.foam,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Libellé d'un bouton ou d'un onglet.
  static const TextStyle label = TextStyle(
    color: AeroColors.foam,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
  static const TextStyle caption = TextStyle(
    color: AeroColors.mist,
    fontFamily: family,
    fontFamilyFallback: fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );
}

/// Dimensions du canevas : toutes les interfaces sont conçues pour cette taille,
/// puis mises à l'échelle de l'écran.
abstract final class AeroMetrics {
  static const Size canvas = Size(1280, 720);

  /// Hauteur de la barre de navigation, posée par-dessus le contenu.
  static const double topBarHeight = 80;
  static const double pagePadding = 40;

  /// Marge des rangées de l'accueil et des fiches : les chevrons s'y logent.
  static const double rowGutter = 64;

  /// Affiche verticale, au format 2:3 des films et des séries.
  static const double cardWidth = 140;
  static const double cardHeight = 210;
  static const double cardSpacing = 18;

  /// Place du titre, sous l'image d'une carte.
  static const double cardTitleHeight = 26;
}
