import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart' hide AppSettings;

const String _groupSeriesKey = 'group_series';
const String _groupChannelsKey = 'group_channels';
const String _liveDelayKey = 'live_delay_seconds';
const String _languageKey = 'language';
const String _activeSourceKey = 'active_source_id';
const String _catalogRulesKey = 'catalog_rules';

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
      _row(_liveDelayKey, '${settings.liveDelaySeconds}'),
      _row(_languageKey, settings.languageCode),
      _row(_catalogRulesKey, '${settings.catalogRules}'),
      if (settings.activeSourceId != null)
        _row(_activeSourceKey, '${settings.activeSourceId}'),
    ]);
  });

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
      liveDelaySeconds:
          int.tryParse(values[_liveDelayKey] ?? '') ??
          defaults.liveDelaySeconds,
      languageCode: values[_languageKey] ?? defaults.languageCode,
      activeSourceId: int.tryParse(values[_activeSourceKey] ?? ''),
      catalogRules:
          int.tryParse(values[_catalogRulesKey] ?? '') ?? defaults.catalogRules,
    );
  }

  bool _readBool(String? value, bool fallback) =>
      value == null ? fallback : value == 'true';
}
