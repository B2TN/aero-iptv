import '../entities/epg_programme.dart';

/// Accès au guide des programmes.
abstract interface class EpgRepository {
  /// Émission en cours pour chaque clé de [epgKeys], à l'instant [at].
  ///
  /// [epgKeys] se limite aux chaînes visibles à l'écran.
  Future<Map<String, EpgProgramme>> nowPlaying(
    int sourceId,
    Iterable<String> epgKeys,
    DateTime at,
  );
}
