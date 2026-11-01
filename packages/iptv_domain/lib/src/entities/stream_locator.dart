/// Moyen de retrouver un flux, sans stocker d'identifiants Xtream.
sealed class StreamLocator {
  const StreamLocator();
}

/// URL complète fournie par une playlist M3U.
final class DirectStream extends StreamLocator {
  const DirectStream(this.url, {this.userAgent, this.referrer});

  final String url;

  /// En-têtes imposés par la playlist via `#EXTVLCOPT` ou la syntaxe `url|...`.
  final String? userAgent;
  final String? referrer;
}

/// Espace de nommage d'un flux Xtream, qui détermine le chemin de son URL.
enum XtreamNamespace {
  live('live'),
  movie('movie'),
  series('series');

  const XtreamNamespace(this.path);

  final String path;
}

/// Référence Xtream. L'URL est construite à la lecture, pour que le mot de
/// passe n'entre jamais dans le catalogue SQLite.
final class XtreamStream extends StreamLocator {
  const XtreamStream({
    required this.namespace,
    required this.streamId,
    required this.extension,
  });

  final XtreamNamespace namespace;
  final int streamId;
  final String extension;
}

/// Flux prêt à être ouvert par le lecteur.
final class ResolvedStream {
  const ResolvedStream({required this.url, this.headers = const {}});

  final String url;
  final Map<String, String> headers;
}
