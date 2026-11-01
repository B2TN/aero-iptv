import 'package:iptv_domain/iptv_domain.dart';

/// Nombre d'émissions par lot d'écriture.
const int epgBatchSize = 500;

/// Paramètres d'un chargement du guide.
final class EpgRequest {
  const EpgRequest({
    required this.credentials,
    required this.knownKeys,
    required this.from,
    required this.to,
    this.discoveredUrl,
  });

  final PlaylistCredentials credentials;

  /// Clés présentes dans le catalogue. Les guides couvrent souvent des milliers
  /// de chaînes absentes de la playlist : elles sont ignorées dès la lecture.
  final Set<String> knownKeys;

  /// Fenêtre conservée.
  final DateTime from;
  final DateTime to;

  /// Guide annoncé par la playlist.
  final String? discoveredUrl;
}

/// Contrat commun aux sources de guide.
abstract interface class EpgSourceAdapter {
  /// Émet les émissions par lots, au fil du téléchargement.
  Stream<List<EpgProgramme>> fetch(EpgRequest request);
}
