import '../entities/stream_locator.dart';

/// Réponse d'un serveur à un flux qui n'a pas pu s'ouvrir.
final class StreamProbeResult {
  const StreamProbeResult({this.status, this.redirectedTo, this.isVideo});

  /// Code HTTP final, `null` si le serveur n'a pas répondu.
  final int? status;

  /// Dernier hôte visité, si le serveur a renvoyé ailleurs. Jamais le chemin :
  /// il contient le mot de passe du compte.
  final String? redirectedTo;

  /// `false` si le serveur a envoyé une page web à la place de la vidéo.
  final bool? isVideo;
}

/// Interroge directement le serveur d'un flux.
abstract interface class StreamProbe {
  /// Retourne `null` si le flux n'est pas accessible en HTTP.
  Future<StreamProbeResult?> probe(ResolvedStream stream);
}
