import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import 'app_state.dart';
import 'di/repository_providers.dart';

/// Heure courante, remplaçable dans les tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Lecteurs ouverts. Un compteur plutôt qu'un drapeau : l'épisode suivant
/// ouvre son lecteur avant que le précédent ne se ferme.
class OpenPlayers extends Notifier<int> {
  @override
  int build() => 0;

  void opened() => state++;

  void closed() => state = math.max(0, state - 1);
}

final openPlayersProvider = NotifierProvider<OpenPlayers, int>(OpenPlayers.new);

/// Synchronisation quotidienne de la playlist affichée : au premier lancement
/// du jour, puis dès que 24 h ont passé, au retour au premier plan ou à la
/// vérification de chaque heure.
///
/// Elle ne démarre jamais pendant une lecture : elle attend la fermeture du
/// lecteur. Commencée, elle continue, même si une lecture démarre ensuite.
class DailySync extends Notifier<void> {
  /// Due pendant une lecture : elle part dès la fermeture du lecteur.
  bool _waiting = false;

  @override
  void build() {
    ref.listen(openPlayersProvider, (_, open) {
      if (open == 0 && _waiting) _start();
    });
  }

  /// Lance la synchronisation si elle est due. [atLaunch] : au lancement de
  /// l'application, une synchronisation d'un autre jour suffit.
  Future<void> check({bool atLaunch = false}) async {
    if (!await _enabled()) return;
    final source = ref.read(activeSourceProvider);
    if (source == null) return;
    final due = isDailySyncDue(
      lastSyncedAt: source.lastSyncedAt,
      now: ref.read(clockProvider)(),
      atLaunch: atLaunch,
    );
    if (!due) return;
    if (ref.read(openPlayersProvider) > 0) {
      _waiting = true;
      return;
    }
    _start();
  }

  void _start() {
    _waiting = false;
    final source = ref.read(activeSourceProvider);
    if (source == null) return;
    // Déjà en cours, l'import l'ignore.
    ref.read(importControllerProvider.notifier).start(source);
  }

  /// Lu dans la base : au lancement, les réglages affichés ne sont peut-être
  /// pas encore arrivés, et un réglage coupé doit être respecté dès le début.
  Future<bool> _enabled() async =>
      (await ref.read(settingsRepositoryProvider).watch().first).dailySync;
}

final dailySyncProvider = NotifierProvider<DailySync, void>(DailySync.new);
