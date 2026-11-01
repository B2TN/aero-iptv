import 'grouping_key.dart';

/// Version de la règle de nettoyage et de regroupement des titres.
///
/// À incrémenter quand ces règles changent : les catalogues déjà importés sont
/// alors réimportés automatiquement.
const int catalogRulesVersion = 4;

/// Série telle que l'import la voit, avant le regroupement final.
final class VersionCandidate {
  const VersionCandidate({
    required this.groupingKey,
    this.title,
    this.label,
    this.year,
    this.posterUrl,
    this.tmdbId,
  });

  final String groupingKey;

  /// Titre nettoyé, qui permet de reconnaître une franchise.
  final String? title;

  /// Version annoncée par le fournisseur : « FR », « DE SUB »...
  final String? label;
  final int? year;
  final String? posterUrl;

  /// Identifiant TMDb fourni par le panneau, s'il en donne un.
  final String? tmdbId;
}

/// Au-delà, une affiche est générique : image d'attente, bandeau d'un bouquet.
const int _maxTitlesPerPoster = 6;

/// Une même série peut être datée à un an près selon les fournisseurs.
const int _maxYearGap = 1;

/// Longueur minimale d'un nom de franchise : « It: », trop court, ne prouve rien.
const int _minFranchiseLength = 5;

/// Taille maximale d'un groupe rattaché à une franchise : au-delà, il s'agit
/// probablement d'une série à part entière.
const int _maxTranslatedVersions = 3;

/// Relie les versions d'une série dont les titres sont traduits.
///
/// Aucun nettoyage de texte ne rapprochera « Dexter: Wiedererwachen » de
/// « Dexter: Resurrection ». Trois indices le peuvent, du plus sûr au moins sûr :
///
/// 1. l'identifiant TMDb ;
/// 2. le fichier d'affiche, que les fournisseurs reprennent de TMDb ;
/// 3. la franchise : même nom avant les deux-points, même année, et aucune
///    langue en commun, car un fournisseur n'a pas deux versions allemandes
///    d'une même série sous deux titres.
abstract final class VersionGrouper {
  /// Retourne, pour chaque clé à fusionner, la clé commune à lui donner.
  static Map<String, String> merge(Iterable<VersionCandidate> entries) {
    final sets = _KeySets();
    final byKey = <String, List<VersionCandidate>>{};
    final byTmdb = <String, Set<String>>{};
    final byPoster = <String, List<VersionCandidate>>{};

    for (final entry in entries) {
      final key = entry.groupingKey;
      (byKey[key] ??= []).add(entry);
      final tmdb = entry.tmdbId?.trim();
      if (tmdb != null && tmdb.isNotEmpty && tmdb != '0') {
        (byTmdb[tmdb] ??= {}).add(key);
      }
      final poster = _posterName(entry.posterUrl);
      if (poster != null) (byPoster[poster] ??= []).add(entry);
    }

    byTmdb.values.forEach(sets.unionAll);
    for (final group in byPoster.values) {
      final keys = {for (final entry in group) entry.groupingKey};
      if (keys.length <= _maxTitlesPerPoster && _yearsAgree(group)) {
        sets.unionAll(keys);
      }
    }
    _mergeFranchises(byKey, sets);

    final components = <String, List<String>>{};
    for (final key in byKey.keys) {
      (components[sets.find(key)] ??= []).add(key);
    }
    final merged = <String, String>{};
    for (final keys in components.values.where((keys) => keys.length > 1)) {
      // La clé la plus fréquente est gardée : ce sont les autres qui changent.
      final common = keys.reduce(
        (a, b) => _rank(byKey, b).compareTo(_rank(byKey, a)) < 0 ? b : a,
      );
      for (final key in keys) {
        if (key != common) merged[key] = common;
      }
    }
    return merged;
  }

  /// Rattache les petits groupes traduits au groupe principal de leur franchise.
  static void _mergeFranchises(
    Map<String, List<VersionCandidate>> byKey,
    _KeySets sets,
  ) {
    final members = <String, List<VersionCandidate>>{};
    for (final entries in byKey.values) {
      (members[sets.find(entries.first.groupingKey)] ??= []).addAll(entries);
    }

    final franchises = <String, List<List<VersionCandidate>>>{};
    for (final group in members.values) {
      final year = _yearOf(group);
      final name = _franchiseOf(group);
      if (year != null && name != null) {
        (franchises['$name#$year'] ??= []).add(group);
      }
    }

    for (final groups in franchises.values) {
      if (groups.length < 2) continue;
      groups.sort((a, b) => b.length.compareTo(a.length));
      final main = groups.first;
      final languages = _languagesOf(main);
      for (final group in groups.skip(1)) {
        final own = _languagesOf(group);
        if (group.length <= _maxTranslatedVersions &&
            own.isNotEmpty &&
            own.intersection(languages).isEmpty) {
          sets.unionAll({main.first.groupingKey, group.first.groupingKey});
          languages.addAll(own);
        }
      }
    }
  }

  /// Rang d'une clé : le plus de versions, puis la clé la plus courte.
  static int _rank(Map<String, List<VersionCandidate>> byKey, String key) =>
      -byKey[key]!.length * 1000 + key.length;

  static int? _yearOf(List<VersionCandidate> group) {
    for (final entry in group) {
      final year = entry.year;
      if (year != null) return year;
    }
    return null;
  }

  static String? _franchiseOf(List<VersionCandidate> group) {
    for (final entry in group) {
      final title = entry.title;
      final colon = title?.indexOf(':') ?? -1;
      if (colon <= 0) continue;
      final name = GroupingKey.of(title!.substring(0, colon));
      if (name.length >= _minFranchiseLength) return name;
    }
    return null;
  }

  /// Langue d'une version, sans ses mentions de qualité ou de sous-titrage.
  static Set<String> _languagesOf(List<VersionCandidate> group) => {
    for (final entry in group)
      if (entry.label != null) entry.label!.split(RegExp('[ -]')).first,
  };

  static bool _yearsAgree(List<VersionCandidate> group) {
    final years = [for (final entry in group) ?entry.year];
    if (years.isEmpty) return true;
    final oldest = years.reduce((a, b) => a < b ? a : b);
    final newest = years.reduce((a, b) => a > b ? a : b);
    return newest - oldest <= _maxYearGap;
  }

  /// Nom du fichier d'une affiche TMDb. Les autres hébergeurs renomment leurs
  /// images : leur nom ne prouve rien.
  static String? _posterName(String? url) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.host.contains('tmdb') && !uri.host.contains('themoviedb')) {
      return null;
    }
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return name.isEmpty ? null : name;
  }
}

/// Ensembles disjoints de clés de regroupement.
final class _KeySets {
  final Map<String, String> _parents = {};

  String find(String key) {
    var current = _parents[key] ?? key;
    while (current != (_parents[current] ?? current)) {
      current = _parents[current]!;
    }
    return _parents[key] = current;
  }

  void unionAll(Set<String> keys) {
    final first = find(keys.first);
    for (final key in keys.skip(1)) {
      _parents[find(key)] = first;
    }
  }
}
