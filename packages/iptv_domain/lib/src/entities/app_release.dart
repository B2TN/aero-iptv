/// Version d'Aero IPTV : `0.2.1`, ou `0.2.1-beta.3` pour une préversion.
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.preRelease]);

  /// Lit `0.2.1`, `v0.2.1-beta.3` ou `0.2.1-beta.3+20` ; `null` sinon.
  static AppVersion? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4),
    );
  }

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  final int major;
  final int minor;
  final int patch;

  /// `beta.3` pour une préversion, `null` pour une version officielle.
  final String? preRelease;

  bool get isPreRelease => preRelease != null;

  /// Ordre de semver : une préversion précède la version officielle, et
  /// `beta.10` suit `beta.9`.
  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) return a.compareTo(b);
    }
    final mine = preRelease;
    final theirs = other.preRelease;
    if (mine == null || theirs == null) {
      if (mine == theirs) return 0;
      return mine == null ? 1 : -1;
    }
    final a = mine.split('.');
    final b = theirs.split('.');
    for (var i = 0; i < a.length && i < b.length; i++) {
      final x = int.tryParse(a[i]);
      final y = int.tryParse(b[i]);
      final order = x != null && y != null
          ? x.compareTo(y)
          : x != null
          ? -1
          : y != null
          ? 1
          : a[i].compareTo(b[i]);
      if (order != 0) return order;
    }
    return a.length.compareTo(b.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease == null ? '' : '-$preRelease'}';
}

/// Fichier joint à une release.
final class ReleaseAsset {
  const ReleaseAsset({required this.url, required this.size});

  final String url;

  /// Taille en octets.
  final int size;
}

/// Version publiée de l'application.
final class AppRelease {
  const AppRelease({
    required this.version,
    required this.tag,
    required this.notes,
    required this.pageUrl,
    this.assets = const {},
    bool? preRelease,
  }) : _preRelease = preRelease;

  final AppVersion version;

  /// Étiquette Git, comme `v0.2.1` : l'utilisateur écarte une release par
  /// elle.
  final String tag;

  /// Notes de version, en Markdown.
  final String notes;

  /// Page de la release sur GitHub.
  final String pageUrl;

  /// Fichiers joints, par nom.
  final Map<String, ReleaseAsset> assets;

  final bool? _preRelease;

  /// Préversion : marquée comme telle à la publication, ou numérotée comme
  /// telle (`0.2.5-beta.1`). Une préversion peut porter un numéro simple,
  /// comme `0.2.5`.
  bool get isPreRelease => _preRelease ?? version.isPreRelease;
}

/// Mise à jour à proposer parmi [releases] : la plus récente, plus récente
/// que [current], officielle sauf si [preReleases]. `null` s'il n'y en a pas,
/// ou si c'est celle que l'utilisateur a écartée ([dismissedTag]).
AppRelease? findUpdate(
  List<AppRelease> releases, {
  required AppVersion current,
  required bool preReleases,
  String? dismissedTag,
}) {
  AppRelease? newest;
  for (final release in releases) {
    if (release.isPreRelease && !preReleases) continue;
    if (!(release.version > current)) continue;
    if (newest == null || release.version > newest.version) newest = release;
  }
  return newest == null || newest.tag == dismissedTag ? null : newest;
}
