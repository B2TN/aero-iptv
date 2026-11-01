import 'package:iptv_domain/iptv_domain.dart';

import 'catalog_batch.dart';

/// Nombre d'entrées par lot : compromis entre mémoire et vitesse d'écriture.
const int catalogBatchSize = 500;

/// Contrat commun aux formats de source.
///
/// Le flux émet des lots au fil du téléchargement : aucune implémentation ne
/// doit charger la playlist complète en mémoire.
abstract interface class PlaylistSourceAdapter {
  Stream<CatalogBatch> fetch(PlaylistCredentials credentials);
}
