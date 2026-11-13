import 'subtitle_style.dart';

/// Réglages de l'application.
final class AppSettings {
  const AppSettings({
    this.groupSeries = true,
    this.groupChannels = true,
    this.liveDelaySeconds = 0,
    this.languageCode = 'fr',
    this.activeSourceId,
    this.catalogRules = 0,
    this.subtitleStyle = const SubtitleStyle(),
  });

  /// Fusion des versions d'une série. Désactivée : vue brute de la playlist.
  final bool groupSeries;

  /// Fusion des qualités d'une chaîne. Désactivée : vue brute de la playlist.
  final bool groupChannels;

  /// Retard ajouté aux chaînes en direct pour stabiliser la lecture.
  final int liveDelaySeconds;

  /// `fr`, `en`, `de`, `es` ou `ar`.
  final String languageCode;

  /// Playlist affichée. `null` désigne la première playlist disponible.
  final int? activeSourceId;

  /// Version des règles de nettoyage appliquées au dernier import.
  final int catalogRules;

  /// Apparence des sous-titres dans le lecteur.
  final SubtitleStyle subtitleStyle;

  AppSettings copyWith({
    bool? groupSeries,
    bool? groupChannels,
    int? liveDelaySeconds,
    String? languageCode,
    int? activeSourceId,
    int? catalogRules,
    SubtitleStyle? subtitleStyle,
  }) => AppSettings(
    groupSeries: groupSeries ?? this.groupSeries,
    groupChannels: groupChannels ?? this.groupChannels,
    liveDelaySeconds: liveDelaySeconds ?? this.liveDelaySeconds,
    languageCode: languageCode ?? this.languageCode,
    activeSourceId: activeSourceId ?? this.activeSourceId,
    catalogRules: catalogRules ?? this.catalogRules,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
  );
}
