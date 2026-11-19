import 'package:iptv_domain/iptv_domain.dart';
import 'package:test/test.dart';

void main() {
  test('suit la numérotation de la TNT', () {
    final names = [
      'Chérie 25',
      'BFM TV',
      'France 2',
      'TF1',
      'Gulli',
      'France 4',
      'LCP Public Sénat',
      'Franceinfo',
      "L'Équipe",
    ];
    names.sort(
      (a, b) => nationalChannelRank(
        'FR',
        a,
      )!.compareTo(nationalChannelRank('FR', b)!),
    );

    expect(names, [
      'TF1',
      'France 2',
      'France 4',
      'LCP Public Sénat',
      'Gulli',
      'BFM TV',
      'Franceinfo',
      "L'Équipe",
      'Chérie 25',
    ]);
  });

  test('range les décrochages régionaux avec leur chaîne', () {
    expect(nationalChannelRank('FR', 'France 3 Alpes'), 3);
    expect(nationalChannelRank('FR', 'France 3'), 3);
    // Un autre numéro n'est pas une déclinaison.
    expect(nationalChannelRank('FR', 'France 24'), isNull);
  });

  test('reconnaît Canal+ et ses variantes de nom', () {
    expect(nationalChannelRank('FR', 'Canal+'), 26);
    expect(nationalChannelRank('FR', 'CANAL PLUS'), 26);
    expect(nationalChannelRank('FR', 'Canal J'), isNull);
  });

  test('chaque pays a sa numérotation', () {
    expect(nationalChannelRank('IT', 'Canale 5'), 5);
    expect(nationalChannelRank('GB', 'BBC One'), 1);
    expect(nationalChannelRank('DE', 'ZDF'), 2);
    // Une chaîne d'un autre pays n'a pas de rang ici.
    expect(nationalChannelRank('FR', 'ZDF'), isNull);
    expect(nationalChannelRank('MA', '2M'), isNull);
    expect(nationalChannelRank(null, 'TF1'), isNull);
  });
}
