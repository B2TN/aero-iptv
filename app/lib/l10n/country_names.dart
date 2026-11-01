/// Noms des pays dans les langues de l'application, dans l'ordre de [_languages].
const List<String> _languages = ['fr', 'en', 'de', 'es', 'ar'];

const Map<String, List<String>> _names = {
  'FR': ['France', 'France', 'Frankreich', 'Francia', 'فرنسا'],
  'GB': [
    'Royaume-Uni',
    'United Kingdom',
    'Vereinigtes Königreich',
    'Reino Unido',
    'المملكة المتحدة',
  ],
  'US': [
    'États-Unis',
    'United States',
    'Vereinigte Staaten',
    'Estados Unidos',
    'الولايات المتحدة',
  ],
  'DE': ['Allemagne', 'Germany', 'Deutschland', 'Alemania', 'ألمانيا'],
  'ES': ['Espagne', 'Spain', 'Spanien', 'España', 'إسبانيا'],
  'IT': ['Italie', 'Italy', 'Italien', 'Italia', 'إيطاليا'],
  'PT': ['Portugal', 'Portugal', 'Portugal', 'Portugal', 'البرتغال'],
  'NL': ['Pays-Bas', 'Netherlands', 'Niederlande', 'Países Bajos', 'هولندا'],
  'BE': ['Belgique', 'Belgium', 'Belgien', 'Bélgica', 'بلجيكا'],
  'CH': ['Suisse', 'Switzerland', 'Schweiz', 'Suiza', 'سويسرا'],
  'AT': ['Autriche', 'Austria', 'Österreich', 'Austria', 'النمسا'],
  'LU': ['Luxembourg', 'Luxembourg', 'Luxemburg', 'Luxemburgo', 'لوكسمبورغ'],
  'IE': ['Irlande', 'Ireland', 'Irland', 'Irlanda', 'أيرلندا'],
  'PL': ['Pologne', 'Poland', 'Polen', 'Polonia', 'بولندا'],
  'RO': ['Roumanie', 'Romania', 'Rumänien', 'Rumanía', 'رومانيا'],
  'GR': ['Grèce', 'Greece', 'Griechenland', 'Grecia', 'اليونان'],
  'TR': ['Turquie', 'Turkey', 'Türkei', 'Turquía', 'تركيا'],
  'RU': ['Russie', 'Russia', 'Russland', 'Rusia', 'روسيا'],
  'UA': ['Ukraine', 'Ukraine', 'Ukraine', 'Ucrania', 'أوكرانيا'],
  'SE': ['Suède', 'Sweden', 'Schweden', 'Suecia', 'السويد'],
  'NO': ['Norvège', 'Norway', 'Norwegen', 'Noruega', 'النرويج'],
  'DK': ['Danemark', 'Denmark', 'Dänemark', 'Dinamarca', 'الدنمارك'],
  'FI': ['Finlande', 'Finland', 'Finnland', 'Finlandia', 'فنلندا'],
  'CZ': ['Tchéquie', 'Czechia', 'Tschechien', 'Chequia', 'التشيك'],
  'HU': ['Hongrie', 'Hungary', 'Ungarn', 'Hungría', 'المجر'],
  'AL': ['Albanie', 'Albania', 'Albanien', 'Albania', 'ألبانيا'],
  'CA': ['Canada', 'Canada', 'Kanada', 'Canadá', 'كندا'],
  'BR': ['Brésil', 'Brazil', 'Brasilien', 'Brasil', 'البرازيل'],
  'MX': ['Mexique', 'Mexico', 'Mexiko', 'México', 'المكسيك'],
  'AR': ['Argentine', 'Argentina', 'Argentinien', 'Argentina', 'الأرجنتين'],
  'MA': ['Maroc', 'Morocco', 'Marokko', 'Marruecos', 'المغرب'],
  'DZ': ['Algérie', 'Algeria', 'Algerien', 'Argelia', 'الجزائر'],
  'TN': ['Tunisie', 'Tunisia', 'Tunesien', 'Túnez', 'تونس'],
  'EG': ['Égypte', 'Egypt', 'Ägypten', 'Egipto', 'مصر'],
  'SA': [
    'Arabie saoudite',
    'Saudi Arabia',
    'Saudi-Arabien',
    'Arabia Saudí',
    'السعودية',
  ],
  'AE': [
    'Émirats arabes unis',
    'United Arab Emirates',
    'Vereinigte Arabische Emirate',
    'Emiratos Árabes Unidos',
    'الإمارات',
  ],
  'LB': ['Liban', 'Lebanon', 'Libanon', 'Líbano', 'لبنان'],
  'IQ': ['Irak', 'Iraq', 'Irak', 'Irak', 'العراق'],
  'IN': ['Inde', 'India', 'Indien', 'India', 'الهند'],
  'PK': ['Pakistan', 'Pakistan', 'Pakistan', 'Pakistán', 'باكستان'],
  'CN': ['Chine', 'China', 'China', 'China', 'الصين'],
  'JP': ['Japon', 'Japan', 'Japan', 'Japón', 'اليابان'],
  'KR': [
    'Corée du Sud',
    'South Korea',
    'Südkorea',
    'Corea del Sur',
    'كوريا الجنوبية',
  ],
  'AU': ['Australie', 'Australia', 'Australien', 'Australia', 'أستراليا'],
  'ZA': [
    'Afrique du Sud',
    'South Africa',
    'Südafrika',
    'Sudáfrica',
    'جنوب أفريقيا',
  ],
  'ARB': [
    'Monde arabe',
    'Arab world',
    'Arabische Welt',
    'Mundo árabe',
    'العالم العربي',
  ],
  'AFR': ['Afrique', 'Africa', 'Afrika', 'África', 'أفريقيا'],
  'LAT': [
    'Amérique latine',
    'Latin America',
    'Lateinamerika',
    'Latinoamérica',
    'أمريكا اللاتينية',
  ],
  'EXYU': [
    'Ex-Yougoslavie',
    'Former Yugoslavia',
    'Ehemaliges Jugoslawien',
    'Ex-Yugoslavia',
    'يوغوسلافيا السابقة',
  ],
}; // dart format width=200

/// Noms des langues proposées, chacun dans sa propre langue.
const Map<String, String> languageNames = {
  'fr': 'Français',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'ar': 'العربية',
};

/// Retourne le nom du pays [code] dans [language].
String? countryName(String code, String language) {
  final names = _names[code];
  if (names == null) return null;
  final index = _languages.indexOf(language);
  return names[index < 0 ? 0 : index];
}

/// Pays connus, pour le choix du pays par défaut.
Iterable<String> get knownCountryCodes => _names.keys;
