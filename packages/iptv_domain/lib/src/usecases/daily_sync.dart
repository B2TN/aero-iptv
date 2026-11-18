/// Écart au-delà duquel une source se resynchronise, application ouverte.
const Duration dailySyncInterval = Duration(hours: 24);

/// Vrai si la synchronisation quotidienne d'une source doit partir : jamais
/// synchronisée ; au lancement de l'application, synchronisée un autre jour ;
/// sinon, il y a 24 h ou plus.
bool isDailySyncDue({
  required DateTime? lastSyncedAt,
  required DateTime now,
  required bool atLaunch,
}) {
  final last = lastSyncedAt;
  if (last == null) return true;
  if (atLaunch) {
    final before = last.toLocal();
    final today = now.toLocal();
    if (before.year != today.year ||
        before.month != today.month ||
        before.day != today.day) {
      return true;
    }
  }
  return now.difference(last) >= dailySyncInterval;
}
