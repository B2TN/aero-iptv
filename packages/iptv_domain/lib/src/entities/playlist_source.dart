/// Format d'une source. L'index est stocké en base.
enum SourceKind { m3u, xtream }

/// Source configurée par l'utilisateur, sans ses identifiants.
final class PlaylistSource {
  const PlaylistSource({
    required this.id,
    required this.name,
    required this.kind,
    this.defaultCountryCode,
    this.lastSyncedAt,
  });

  final int id;
  final String name;
  final SourceKind kind;

  /// Pays ouvert directement dans Live TV, sans passer par les drapeaux.
  final String? defaultCountryCode;
  final DateTime? lastSyncedAt;
}

/// Identifiants d'une source, conservés dans le stockage sécurisé.
sealed class PlaylistCredentials {
  const PlaylistCredentials();

  /// Format de source correspondant à ces identifiants.
  SourceKind get kind;

  /// Représentation plate pour le stockage sécurisé.
  Map<String, String> toMap();

  /// Reconstruit les identifiants depuis [toMap].
  static PlaylistCredentials fromMap(Map<String, String> map) =>
      switch (map['kind']) {
        'm3u' => M3uCredentials(
          playlistUrl: map['playlistUrl']!,
          epgUrl: map['epgUrl'],
        ),
        'xtream' => XtreamCredentials(
          serverUrl: map['serverUrl']!,
          username: map['username']!,
          password: map['password']!,
        ),
        final kind => throw ArgumentError.value(kind, 'kind'),
      };
}

/// Source M3U. Son URL contient souvent un jeton d'abonné.
final class M3uCredentials extends PlaylistCredentials {
  const M3uCredentials({required this.playlistUrl, this.epgUrl});

  final String playlistUrl;

  /// Guide XMLTV saisi par l'utilisateur. Il remplace celui de la playlist.
  final String? epgUrl;

  @override
  SourceKind get kind => SourceKind.m3u;

  @override
  Map<String, String> toMap() => {
    'kind': 'm3u',
    'playlistUrl': playlistUrl,
    'epgUrl': ?epgUrl,
  };
}

/// Compte Xtream Codes.
final class XtreamCredentials extends PlaylistCredentials {
  const XtreamCredentials({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;

  @override
  SourceKind get kind => SourceKind.xtream;

  @override
  Map<String, String> toMap() => {
    'kind': 'xtream',
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
  };
}
