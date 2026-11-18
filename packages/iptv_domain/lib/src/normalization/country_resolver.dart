import 'country_catalog.dart';

/// Détermine le pays d'une chaîne à partir des indices de la playlist.
final class CountryResolver {
  const CountryResolver();

  /// Applique les indices du plus fiable au moins fiable.
  ///
  /// [groupCountry] et [nameCountry] sont les pays extraits des étiquettes du
  /// groupe et du nom par [TitleCleaner]. Un fichier peut déclarer plusieurs
  /// pays dans `tvg-country`, séparés par `;` ou `,` : le premier est retenu.
  ///
  /// Un groupe de pays l'emporte sur la chaîne. Un groupe de région, comme
  /// « Afrique » ou « Monde arabe », cède au contraire aux indices de la
  /// chaîne : son préfixe (`TN|`), son `tvg-id` (`….tn`), puis un nom de pays
  /// dans son [name]. Sans indice, elle reste dans la région.
  String? resolve({
    String? tvgCountry,
    String? groupCountry,
    String? groupTitle,
    String? nameCountry,
    String? tvgId,
    String? name,
  }) {
    final declared = tvgCountry?.split(RegExp('[;,]')).first.trim();
    final fromDeclared = declared == null || declared.isEmpty
        ? null
        : CountryCatalog.fromPrefix(declared);
    if (fromDeclared != null) return fromDeclared;
    final group =
        groupCountry ??
        (groupTitle == null ? null : CountryCatalog.fromText(groupTitle));
    if (group != null && !CountryCatalog.isRegion(group)) return group;
    final channel =
        nameCountry ??
        (tvgId == null ? null : CountryCatalog.fromTvgId(tvgId)) ??
        (name == null ? null : CountryCatalog.fromText(name));
    // Une région de la chaîne ne précise rien de plus que celle du groupe.
    if (channel == null ||
        (group != null && CountryCatalog.isRegion(channel))) {
      return group ?? channel;
    }
    return channel;
  }
}
