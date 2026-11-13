import 'package:flutter/widgets.dart';

/// Palette Frutiger Aero, sur fond d'eau profonde. `leaf` est réservé à
/// l'élément actif : ce vert d'eau se repère de loin sur le bleu.
abstract final class AeroColors {
  static const Color lagoon = Color(0xFF1E6FB5);
  static const Color aqua = Color(0xFF7FE3FF);
  static const Color foam = Color(0xFFEAF8FF);
  static const Color abyss = Color(0xFF04142B);
  static const Color leaf = Color(0xFF8CF5B4);
  static const Color mist = Color(0xC4CFE9F5);
  static const Color veil = Color(0xB804142B);
  static const Color progressStart = Color(0xFF34C77B);
  static const Color progressEnd = Color(0xFF2F86D8);
}

/// Textures générées par `tool/render_aero_textures_test.dart`, à l'échelle 2.
abstract final class AeroAssets {
  static const double scale = 2;

  static const String background = 'assets/aero/backgrounds/abyss.jpg';
  static const String focusHalo = 'assets/aero/focus/focus_halo.png';
  static const String focusPill = 'assets/aero/focus/focus_pill.png';
  static const String cardFrame = 'assets/aero/chrome/card_frame.png';
  static const String cardGhost = 'assets/aero/chrome/card_ghost.png';
  static const String heroFrame = 'assets/aero/chrome/hero_frame.png';
  static const String heroGloss = 'assets/aero/chrome/hero_gloss.png';
  static const String edgeFlare = 'assets/aero/chrome/edge_flare.png';
  static const String rowContinue = 'assets/aero/icons/row_continue.png';
  static const String rowSeries = 'assets/aero/icons/row_series.png';
  static const String rowMovies = 'assets/aero/icons/row_movies.png';
  static const String chevron = 'assets/aero/icons/chevron.png';
}

/// Échelle typographique. Les titres sont en graisse légère, comme sous Vista :
/// c'est ce qui donne à la police système son caractère.
abstract final class AeroText {
  static const List<Shadow> _lift = [
    Shadow(color: Color(0xCC04142B), offset: Offset(0, 1), blurRadius: 4),
  ];

  static const TextStyle display = TextStyle(
    color: AeroColors.foam,
    fontSize: 34,
    fontWeight: FontWeight.w300,
    height: 1.12,
    shadows: _lift,
  );
  static const TextStyle title = TextStyle(
    color: AeroColors.foam,
    fontSize: 26,
    fontWeight: FontWeight.w300,
    height: 1.2,
    shadows: _lift,
  );
  static const TextStyle heading = TextStyle(
    color: AeroColors.foam,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    height: 1.25,
    shadows: _lift,
  );
  static const TextStyle body = TextStyle(
    color: AeroColors.foam,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    color: AeroColors.mist,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}

/// Dimensions du canevas : toutes les interfaces sont conçues pour cette taille,
/// puis mises à l'échelle de l'écran.
abstract final class AeroMetrics {
  static const Size canvas = Size(1280, 720);
  static const double topBarHeight = 96;
  static const double pagePadding = 40;

  /// Marge des rangées de l'accueil : les chevrons s'y logent.
  static const double rowGutter = 64;

  /// Affiche verticale, au format 2:3 des films et des séries.
  static const double cardWidth = 128;
  static const double cardHeight = 192;
  static const double cardSpacing = 16;

  /// Place du titre et de la barre d'avancement, sous l'image d'une carte.
  static const double cardTitleHeight = 24;
  static const double cardProgressHeight = 14;
}
