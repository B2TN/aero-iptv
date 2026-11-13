import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart' hide AppSettings;

const String _groupSeriesKey = 'group_series';
const String _groupChannelsKey = 'group_channels';
const String _groupMoviesKey = 'group_movies';
const String _liveDelayKey = 'live_delay_seconds';
const String _languageKey = 'language';
const String _activeSourceKey = 'active_source_id';
const String _catalogRulesKey = 'catalog_rules';
const String _subtitleSizeKey = 'subtitle_size';
const String _subtitleFontKey = 'subtitle_font';
const String _subtitleColorKey = 'subtitle_color';
const String _subtitleEdgeKey = 'subtitle_edge';
const String _subtitleBackgroundKey = 'subtitle_background';
const String _subtitleOpacityKey = 'subtitle_background_opacity';
const String _subtitlePositionKey = 'subtitle_position';

/// Réglages stockés sous forme de paires clé-valeur.
final class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() =>
      _db.select(_db.appSettings).watch().map(_fromRows);

  @override
  Future<void> save(AppSettings settings) => _db.batch((batch) {
    batch.insertAllOnConflictUpdate(_db.appSettings, [
      _row(_groupSeriesKey, '${settings.groupSeries}'),
      _row(_groupChannelsKey, '${settings.groupChannels}'),
      _row(_groupMoviesKey, '${settings.groupMovies}'),
      _row(_liveDelayKey, '${settings.liveDelaySeconds}'),
      _row(_languageKey, settings.languageCode),
      _row(_catalogRulesKey, '${settings.catalogRules}'),
      ..._subtitleRows(settings.subtitleStyle),
      if (settings.activeSourceId != null)
        _row(_activeSourceKey, '${settings.activeSourceId}'),
    ]);
  });

  List<AppSettingsCompanion> _subtitleRows(SubtitleStyle style) => [
    _row(_subtitleSizeKey, style.size.name),
    _row(_subtitleFontKey, style.font.name),
    _row(_subtitleColorKey, style.color.name),
    _row(_subtitleEdgeKey, style.edge.name),
    _row(_subtitleBackgroundKey, style.background.name),
    _row(_subtitleOpacityKey, '${style.backgroundOpacity}'),
    _row(_subtitlePositionKey, style.position.name),
  ];

  AppSettingsCompanion _row(String key, String value) =>
      AppSettingsCompanion.insert(settingKey: key, settingValue: value);

  /// Une clé absente garde sa valeur par défaut.
  AppSettings _fromRows(List<AppSettingRow> rows) {
    final values = {for (final row in rows) row.settingKey: row.settingValue};
    const defaults = AppSettings();
    return AppSettings(
      groupSeries: _readBool(values[_groupSeriesKey], defaults.groupSeries),
      groupChannels: _readBool(
        values[_groupChannelsKey],
        defaults.groupChannels,
      ),
      groupMovies: _readBool(values[_groupMoviesKey], defaults.groupMovies),
      liveDelaySeconds:
          int.tryParse(values[_liveDelayKey] ?? '') ??
          defaults.liveDelaySeconds,
      languageCode: values[_languageKey] ?? defaults.languageCode,
      activeSourceId: int.tryParse(values[_activeSourceKey] ?? ''),
      catalogRules:
          int.tryParse(values[_catalogRulesKey] ?? '') ?? defaults.catalogRules,
      subtitleStyle: _readSubtitleStyle(values),
    );
  }

  /// Une valeur inconnue, par exemple d'une version plus récente, garde la
  /// valeur par défaut.
  SubtitleStyle _readSubtitleStyle(Map<String, String> values) {
    const defaults = SubtitleStyle();
    T read<T extends Enum>(List<T> all, String key, T fallback) =>
        all.where((value) => value.name == values[key]).firstOrNull ?? fallback;
    final opacity = int.tryParse(values[_subtitleOpacityKey] ?? '');
    return SubtitleStyle(
      size: read(SubtitleSize.values, _subtitleSizeKey, defaults.size),
      font: read(SubtitleFont.values, _subtitleFontKey, defaults.font),
      color: read(SubtitleColor.values, _subtitleColorKey, defaults.color),
      edge: read(SubtitleEdge.values, _subtitleEdgeKey, defaults.edge),
      background: read(
        SubtitleBackground.values,
        _subtitleBackgroundKey,
        defaults.background,
      ),
      backgroundOpacity: SubtitleStyle.opacities.contains(opacity)
          ? opacity!
          : defaults.backgroundOpacity,
      position: read(
        SubtitlePosition.values,
        _subtitlePositionKey,
        defaults.position,
      ),
    );
  }

  bool _readBool(String? value, bool fallback) =>
      value == null ? fallback : value == 'true';
}
