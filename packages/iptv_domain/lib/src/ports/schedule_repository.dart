import '../entities/show_schedule.dart';

/// Calendrier de diffusion des séries, tiré d'une base publique.
abstract interface class ScheduleRepository {
  /// Calendrier de la série nommée exactement [title] et, si [year] est
  /// connue, commencée cette année-là. `null` si aucune série ne correspond
  /// sûrement : un homonyme donnerait de fausses dates.
  ///
  /// Lève une `Failure` si la base est injoignable.
  Future<ShowSchedule?> scheduleOf(String title, {int? year});
}
