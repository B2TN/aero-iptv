import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iptv_domain/iptv_domain.dart';

import '../../app/app_state.dart';
import '../../app/di/repository_providers.dart';

/// Favoris de la playlist active, tenus à jour à chaque ajout ou retrait.
final favoritesProvider = StreamProvider<List<Favorite>>((ref) {
  final source = ref.watch(activeSourceProvider);
  if (source == null) return Stream.value(const []);
  return ref.watch(favoritesRepositoryProvider).watch(source.id);
});

/// Clé de favori d'une chaîne : son pays et sa clé de regroupement, car deux
/// pays peuvent avoir une chaîne du même nom.
String channelFavoriteKey(Channel channel) =>
    '${channel.countryCode ?? ''}|${channel.groupingKey}';

/// Pays et clé de regroupement d'une chaîne, relus dans sa clé de favori.
({String? countryCode, String groupingKey}) channelKeyOf(String key) {
  final separator = key.indexOf('|');
  final country = separator <= 0 ? null : key.substring(0, separator);
  return (countryCode: country, groupingKey: key.substring(separator + 1));
}

/// Clé de favori d'un film : sa fiche, que partagent toutes ses versions.
String movieFavoriteKey(Movie movie) => movie.groupingKey;

/// Vrai si le contenu [key] de nature [kind] est en favori.
///
/// Lu dans la base et non dans [favoritesProvider] : un fournisseur que
/// personne n'écoute, comme depuis la recherche, est mis en pause et
/// garderait un état périmé.
Future<bool> isFavorite(WidgetRef ref, ContentKind kind, String key) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return false;
  final favorites = await ref
      .read(favoritesRepositoryProvider)
      .watch(source.id)
      .first;
  return favorites.any(
    (favorite) => favorite.kind == kind && favorite.key == key,
  );
}

/// Ajoute ou retire un favori, selon qu'il y est déjà.
Future<void> toggleFavorite(
  WidgetRef ref, {
  required ContentKind kind,
  required String key,
  required String title,
  String? posterUrl,
}) async {
  final source = ref.read(activeSourceProvider);
  if (source == null) return;
  final favorites = ref.read(favoritesRepositoryProvider);
  if (await isFavorite(ref, kind, key)) {
    await favorites.remove(source.id, kind, key);
  } else {
    await favorites.add(
      Favorite(
        sourceId: source.id,
        kind: kind,
        key: key,
        title: title,
        posterUrl: posterUrl,
        addedAt: DateTime.now(),
      ),
    );
  }
}
