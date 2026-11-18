import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 11, 18, 9);

  test('une source jamais synchronisée l est tout de suite', () {
    expect(
      isDailySyncDue(lastSyncedAt: null, now: now, atLaunch: false),
      isTrue,
    );
  });

  test('au premier lancement du jour, même moins de 24 h après', () {
    final lastNight = DateTime(2026, 11, 17, 23);

    expect(
      isDailySyncDue(lastSyncedAt: lastNight, now: now, atLaunch: true),
      isTrue,
    );
    // Application restée ouverte : il faut attendre 24 h.
    expect(
      isDailySyncDue(lastSyncedAt: lastNight, now: now, atLaunch: false),
      isFalse,
    );
  });

  test('pas deux fois le même jour au lancement', () {
    final thisMorning = DateTime(2026, 11, 18, 7);

    expect(
      isDailySyncDue(lastSyncedAt: thisMorning, now: now, atLaunch: true),
      isFalse,
    );
  });

  test('application ouverte, toutes les 24 h', () {
    expect(
      isDailySyncDue(
        lastSyncedAt: now.subtract(const Duration(hours: 24)),
        now: now,
        atLaunch: false,
      ),
      isTrue,
    );
    expect(
      isDailySyncDue(
        lastSyncedAt: now.subtract(const Duration(hours: 23, minutes: 59)),
        now: now,
        atLaunch: false,
      ),
      isFalse,
    );
  });
}
