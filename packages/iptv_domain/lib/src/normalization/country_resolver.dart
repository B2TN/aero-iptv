import 'country_catalog.dart';

/// Détermine le pays d'une chaîne à partir des indices de la playlist.
final class CountryResolver {
  const CountryResolver();

  /// Applique les indices du plus fiable au moins fiable.
  ///
  /// [groupCountry] et [nameCountry] sont les pays extraits des étiquettes du
  /// groupe et du nom par [TitleCleaner]. Un fichier peut déclarer plusieurs
  /// pays dans `tvg-country`, séparés par `;` ou `,` : le premier est retenu.
  String? resolve({
    String? tvgCountry,
    String? groupCountry,
    String? groupTitle,
    String? nameCountry,
    String? tvgId,
  }) {
    final declared = tvgCountry?.split(RegExp('[;,]')).first.trim();
    return (declared == null || declared.isEmpty
            ? null
            : CountryCatalog.fromPrefix(declared)) ??
        groupCountry ??
        (groupTitle == null ? null : CountryCatalog.fromText(groupTitle)) ??
        nameCountry ??
        (tvgId == null ? null : CountryCatalog.fromTvgId(tvgId));
  }
}
