import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

WatchProgress _at(int minutes, {int of = 40, bool finished = false}) =>
    WatchProgress(
      sourceId: 1,
      contentKey: 'x:m:1',
      kind: ContentKind.movie,
      title: 'Lagon',
      position: Duration(minutes: minutes),
      duration: Duration(minutes: of),
      updatedAt: DateTime.utc(2026, 11, 18),
      locator: const DirectStream('http://s/1.mkv'),
      finished: finished,
    );

void main() {
  test('l avancement va de 0 à 1', () {
    expect(_at(10).fraction, 0.25);
    expect(_at(10).inProgress, isTrue);
  });

  test('vu jusqu au bout, il est complet et n est plus en cours', () {
    final done = _at(38, finished: true);

    expect(done.fraction, 1);
    expect(done.inProgress, isFalse);
  });

  test('sans durée ni position, rien n est commencé', () {
    final next = _at(0, of: 0);

    expect(next.fraction, 0);
    expect(next.inProgress, isFalse);
  });
}
