import 'package:flutter/widgets.dart';

/// Apparence de l'interface.
enum AeroLook {
  /// Verre dépoli, reliefs et reflets. Plus gourmande en calcul graphique.
  aero,

  /// Mêmes écrans, panneaux opaques, sans flou ni reflet : pour les petits
  /// appareils comme le Fire TV Stick.
  performance;

  bool get isPerformance => this == AeroLook.performance;

  /// Apparence en vigueur sous [context]. Sans réglage, le mode Aero.
  static AeroLook of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AeroLookScope>()?.look ??
      AeroLook.aero;
}

/// Transmet l'apparence choisie à tous les composants.
class AeroLookScope extends InheritedWidget {
  const AeroLookScope({required this.look, required super.child, super.key});

  final AeroLook look;

  @override
  bool updateShouldNotify(AeroLookScope oldWidget) => look != oldWidget.look;
}

/// Couleurs du mode Performance : des aplats, sans transparence à mélanger.
abstract final class PerformanceColors {
  static const Color panel = Color(0xFF0B2A4D);
  static const Color panelBorder = Color(0xFF2C5A8A);
  static const Color button = Color(0xFF1A4878);
  static const Color buttonBorder = Color(0xFF3B76B0);
  static const Color play = Color(0xFF8BE36A);
}
