import '../entities/app_settings.dart';

/// Persistance des réglages.
abstract interface class SettingsRepository {
  /// Émet les réglages courants, puis chaque modification.
  Stream<AppSettings> watch();

  Future<void> save(AppSettings settings);
}
