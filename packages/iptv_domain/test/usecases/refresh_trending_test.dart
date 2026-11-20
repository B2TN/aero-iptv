import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

final class _Trending implements TrendingRepository {
  _Trending({this.last, this.isAvailable = true, this.failure});

  DateTime? last;
  final Failure? failure;
  final List<String> refreshed = [];

  @override
  final bool isAvailable;

  @override
  Future<List<TrendingItem>> popular(
    ContentKind kind, {
    String? region,
  }) async => const [];

  @override
  Future<DateTime?> refreshedAt(String region) async => last;

  @override
  Future<void> refresh(String region, {required String language}) async {
    final error = failure;
    if (error != null) throw error;
    refreshed.add(region);
  }
}

void main() {
  final now = DateTime.utc(2026, 11, 19, 20);

  test('charge les tendances jamais chargées', () async {
    final trending = _Trending();

    expect(
      await RefreshTrending(trending, clock: () => now)('FR', language: 'fr'),
      isTrue,
    );
    expect(trending.refreshed, ['FR']);
  });

  test('garde les tendances de moins d un jour', () async {
    final trending = _Trending(last: now.subtract(const Duration(hours: 5)));

    expect(
      await RefreshTrending(trending, clock: () => now)('FR', language: 'fr'),
      isFalse,
    );
    expect(trending.refreshed, isEmpty);
  });

  test('actualise tout de suite quand la langue change', () async {
    final trending = _Trending(last: now.subtract(const Duration(hours: 5)));

    expect(
      await RefreshTrending(trending, clock: () => now)(
        'FR',
        language: 'en',
        force: true,
      ),
      isTrue,
    );
    expect(trending.refreshed, ['FR']);
  });

  test('actualise les tendances de la veille', () async {
    final trending = _Trending(last: now.subtract(const Duration(hours: 21)));

    expect(
      await RefreshTrending(trending, clock: () => now)('FR', language: 'fr'),
      isTrue,
    );
    expect(trending.refreshed, ['FR']);
  });

  test('sans service, ne demande rien', () async {
    final trending = _Trending(isAvailable: false);

    expect(
      await RefreshTrending(trending, clock: () => now)('FR', language: 'fr'),
      isFalse,
    );
    expect(trending.refreshed, isEmpty);
  });

  test('signale l échec des services', () {
    final trending = _Trending(failure: const NetworkFailure('hors ligne'));

    expect(
      RefreshTrending(trending, clock: () => now)('FR', language: 'fr'),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
