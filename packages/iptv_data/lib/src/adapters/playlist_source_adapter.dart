import 'package:iptv_domain/iptv_domain.dart';

import 'catalog_batch.dart';

/// Nombre d'entrées par lot : compromis entre mémoire et vitesse d'écriture.
const int catalogBatchSize = 500;

/// Décide, pendant une synchronisation, si une entrée reçue mérite d'être
/// traitée : [identity] la reconnaît d'un catalogue à l'autre (`x:m:123`),
/// [hash] résume ce que l'application en lit. [legacy] donne l'empreinte de
/// tout son texte, celle d'avant la version 2 des empreintes, que seule la
/// synchronisation de transition demande. Une entrée refusée n'est ni
/// décodée ni livrée.
typedef EntryGate =
    bool Function(String identity, int hash, int Function() legacy);

/// Partie d'une source, téléchargée d'un seul tenant.
///
/// Ce découpage permet de reprendre une partie sans tout recommencer, et de
/// garder les autres si l'une d'elles reste en échec.
final class SourceSection {
  const SourceSection(this.kind, this.fetch, {this.fetchChanges});

  /// Nature des entrées. `null` si la section les mêle toutes, comme un fichier
  /// M3U.
  final ContentKind? kind;

  /// Télécharge la section. Chaque appel repart du début.
  ///
  /// Le flux émet des lots au fil du téléchargement : aucune implémentation ne
  /// doit charger la section complète en mémoire.
  final Stream<CatalogBatch> Function() fetch;

  /// Comme [fetch], mais ne livre que les entrées que la porte accepte.
  /// `null` si la source ne sait pas reconnaître ses entrées avant de les
  /// décoder.
  final Stream<CatalogBatch> Function(EntryGate gate)? fetchChanges;
}

/// Contrat commun aux formats de source.
abstract interface class PlaylistSourceAdapter {
  /// Vérifie l'accès à la source, puis retourne ses sections dans l'ordre où
  /// les télécharger.
  Future<List<SourceSection>> open(PlaylistCredentials credentials);
}

/// Lecture d'une source entière, sans reprise.
extension WholeSource on PlaylistSourceAdapter {
  Stream<CatalogBatch> fetch(PlaylistCredentials credentials) async* {
    for (final section in await open(credentials)) {
      yield* section.fetch();
    }
  }
}
