import 'text_folding.dart';

/// Pays reconnu, avec ses préfixes de playlist et ses noms courants.
final class _CountryInfo {
  const _CountryInfo(this.code, this.prefixes, this.names);

  final String code;
  final List<String> prefixes;
  final List<String> names;
}

/// Dictionnaire des pays. Pour en ajouter un, il suffit d'ajouter une ligne.
///
/// Les codes ambigus ne servent pas de préfixe, car un préfixe reconnu est
/// retiré du titre : `TV` (Tuvalu), `SD` (Soudan, aussi une qualité), `MR`,
/// `CO`, `CD`, `DJ`, `IL`, `SI`, `OM`… Ces pays se reconnaissent à leur nom.
/// Les prénoms courants, comme « Maurice », n'en font pas partie.
///
/// `ARB`, `AFR`, `LAT` et `EXYU` sont des pseudo-codes : les fournisseurs
/// classent souvent leurs chaînes par région. `AR` désigne l'arabe et non
/// l'Argentine, dont le préfixe reste `ARG`.
const List<_CountryInfo> _countries = [
  _CountryInfo(
    'FR',
    ['FR', 'FRA'],
    ['FRANCE', 'FRENCH', 'FRANÇAIS', 'FRANÇAISE'],
  ),
  _CountryInfo(
    'GB',
    ['UK', 'GB', 'EN', 'ENG'],
    ['UNITED KINGDOM', 'ROYAUME UNI', 'BRITISH', 'ENGLAND', 'ANGLETERRE'],
  ),
  _CountryInfo(
    'US',
    ['US', 'USA'],
    ['UNITED STATES', 'ÉTATS UNIS', 'ETATS UNIS', 'USA', 'AMERICA'],
  ),
  _CountryInfo(
    'DE',
    ['DE', 'GER', 'DEU'],
    ['GERMANY', 'ALLEMAGNE', 'DEUTSCHLAND', 'GERMAN', 'DEUTSCH'],
  ),
  _CountryInfo(
    'ES',
    ['ES', 'ESP'],
    ['SPAIN', 'ESPAGNE', 'ESPAÑA', 'SPANISH', 'ESPAÑOL'],
  ),
  _CountryInfo('IT', ['IT', 'ITA'], ['ITALY', 'ITALIE', 'ITALIA', 'ITALIAN']),
  _CountryInfo('PT', ['PT', 'POR'], ['PORTUGAL', 'PORTUGUESE']),
  _CountryInfo(
    'NL',
    ['NL'],
    ['NETHERLANDS', 'PAYS BAS', 'HOLLAND', 'NEDERLAND', 'DUTCH'],
  ),
  _CountryInfo('BE', ['BE'], ['BELGIUM', 'BELGIQUE', 'BELGIË']),
  _CountryInfo('CH', ['CH'], ['SWITZERLAND', 'SUISSE', 'SCHWEIZ']),
  _CountryInfo('AT', ['AT'], ['AUSTRIA', 'AUTRICHE', 'ÖSTERREICH']),
  _CountryInfo('LU', ['LU'], ['LUXEMBOURG']),
  _CountryInfo('IE', ['IE'], ['IRELAND', 'IRLANDE']),
  _CountryInfo('PL', ['PL', 'POL'], ['POLAND', 'POLOGNE', 'POLSKA']),
  _CountryInfo('RO', ['RO'], ['ROMANIA', 'ROUMANIE']),
  _CountryInfo('GR', ['GR'], ['GREECE', 'GRÈCE']),
  _CountryInfo(
    'TR',
    ['TR', 'TUR'],
    ['TURKEY', 'TURQUIE', 'TÜRKIYE', 'TURKISH'],
  ),
  _CountryInfo('RU', ['RU', 'RUS'], ['RUSSIA', 'RUSSIE']),
  _CountryInfo('UA', ['UA'], ['UKRAINE']),
  _CountryInfo('SE', ['SE'], ['SWEDEN', 'SUÈDE', 'SVERIGE']),
  _CountryInfo('NO', ['NO'], ['NORWAY', 'NORVÈGE', 'NORGE']),
  _CountryInfo('DK', ['DK'], ['DENMARK', 'DANEMARK', 'DANMARK']),
  _CountryInfo('FI', ['FI'], ['FINLAND', 'FINLANDE', 'SUOMI']),
  _CountryInfo('CZ', ['CZ'], ['CZECH', 'TCHÉQUIE']),
  _CountryInfo('HU', ['HU'], ['HUNGARY', 'HONGRIE']),
  _CountryInfo('AL', ['AL'], ['ALBANIA', 'ALBANIE']),
  _CountryInfo('CA', ['CA'], ['CANADA', 'QUÉBEC', 'QUEBEC']),
  _CountryInfo('BR', ['BR'], ['BRAZIL', 'BRÉSIL', 'BRASIL']),
  _CountryInfo('MX', ['MX'], ['MEXICO', 'MEXIQUE']),
  _CountryInfo('AR', ['ARG'], ['ARGENTINA', 'ARGENTINE']),
  _CountryInfo('MA', ['MA'], ['MOROCCO', 'MAROC', 'المغرب']),
  _CountryInfo('DZ', ['DZ', 'ALG'], ['ALGERIA', 'ALGÉRIE', 'الجزائر']),
  _CountryInfo('TN', ['TN', 'TUN'], ['TUNISIA', 'TUNISIE', 'تونس']),
  _CountryInfo('EG', ['EG'], ['EGYPT', 'ÉGYPTE', 'مصر', 'MASR', 'MISR']),
  _CountryInfo('SA', ['SA', 'KSA'], ['SAUDI', 'ARABIE SAOUDITE', 'السعودية']),
  _CountryInfo(
    'AE',
    ['AE', 'UAE'],
    ['EMIRATES', 'ÉMIRATS', 'DUBAI', 'الإمارات'],
  ),
  _CountryInfo('LB', ['LB'], ['LEBANON', 'LIBAN', 'لبنان']),
  _CountryInfo('IQ', ['IQ'], ['IRAQ', 'IRAK', 'العراق']),
  _CountryInfo('IN', ['IN'], ['INDIA', 'INDE']),
  _CountryInfo('PK', ['PK'], ['PAKISTAN']),
  _CountryInfo('CN', ['CN'], ['CHINA', 'CHINE']),
  _CountryInfo('JP', ['JP'], ['JAPAN', 'JAPON']),
  _CountryInfo('KR', ['KR'], ['KOREA', 'CORÉE']),
  _CountryInfo('AU', ['AU'], ['AUSTRALIA', 'AUSTRALIE']),
  _CountryInfo('ZA', ['ZA'], ['SOUTH AFRICA', 'AFRIQUE DU SUD']),
  _CountryInfo(
    'IS',
    ['ISL'],
    ['ICELAND', 'ISLANDE', 'ISLAND', 'ISLANDIA', 'آيسلندا'],
  ),
  _CountryInfo(
    'EE',
    ['EE', 'EST'],
    ['ESTONIA', 'ESTONIE', 'ESTLAND', 'إستونيا', 'EESTI'],
  ),
  _CountryInfo(
    'LV',
    ['LV'],
    ['LATVIA', 'LETTONIE', 'LETTLAND', 'LETONIA', 'لاتفيا'],
  ),
  _CountryInfo(
    'LT',
    ['LT'],
    ['LITHUANIA', 'LITUANIE', 'LITAUEN', 'LITUANIA', 'ليتوانيا'],
  ),
  _CountryInfo(
    'SK',
    ['SK'],
    ['SLOVAKIA', 'SLOVAQUIE', 'SLOWAKEI', 'ESLOVAQUIA', 'سلوفاكيا'],
  ),
  _CountryInfo(
    'SI',
    ['SLO'],
    ['SLOVENIA', 'SLOVÉNIE', 'SLOWENIEN', 'ESLOVENIA', 'سلوفينيا'],
  ),
  _CountryInfo(
    'HR',
    ['HR', 'CRO'],
    ['CROATIA', 'CROATIE', 'KROATIEN', 'CROACIA', 'كرواتيا', 'HRVATSKA'],
  ),
  _CountryInfo(
    'BA',
    ['BA', 'BIH'],
    [
      'BOSNIA AND HERZEGOVINA',
      'BOSNIE-HERZÉGOVINE',
      'BOSNIEN UND HERZEGOWINA',
      'BOSNIA Y HERZEGOVINA',
      'البوسنة والهرسك',
      'BOSNIA',
      'BOSNIE',
    ],
  ),
  _CountryInfo(
    'RS',
    ['RS', 'SRB'],
    ['SERBIA', 'SERBIE', 'SERBIEN', 'صربيا', 'SRBIJA'],
  ),
  _CountryInfo(
    'ME',
    ['MNE'],
    ['MONTENEGRO', 'MONTÉNÉGRO', 'الجبل الأسود', 'CRNA GORA'],
  ),
  _CountryInfo(
    'MK',
    ['MK', 'MKD'],
    [
      'NORTH MACEDONIA',
      'MACÉDOINE DU NORD',
      'NORDMAZEDONIEN',
      'MACEDONIA DEL NORTE',
      'مقدونيا الشمالية',
      'MACEDONIA',
      'MACÉDOINE',
    ],
  ),
  _CountryInfo('XK', ['XK', 'KOS'], ['KOSOVO', 'كوسوفو']),
  _CountryInfo(
    'BG',
    ['BG', 'BUL'],
    ['BULGARIA', 'BULGARIE', 'BULGARIEN', 'بلغاريا'],
  ),
  _CountryInfo('MD', [], [
    'MOLDOVA',
    'MOLDAVIE',
    'MOLDAU',
    'MOLDAVIA',
    'مولدوفا',
  ]),
  _CountryInfo(
    'BY',
    ['BLR'],
    ['BELARUS', 'BIÉLORUSSIE', 'BIELORRUSIA', 'بيلاروس'],
  ),
  _CountryInfo('MT', ['MT'], ['MALTA', 'MALTE', 'مالطا']),
  _CountryInfo('CY', ['CY'], ['CYPRUS', 'CHYPRE', 'ZYPERN', 'CHIPRE', 'قبرص']),
  _CountryInfo('GE', ['GE'], ['GEORGIA', 'GÉORGIE', 'GEORGIEN', 'جورجيا']),
  _CountryInfo('AM', ['ARM'], ['ARMENIA', 'ARMÉNIE', 'ARMENIEN', 'أرمينيا']),
  _CountryInfo(
    'AZ',
    ['AZ', 'AZE'],
    ['AZERBAIJAN', 'AZERBAÏDJAN', 'ASERBAIDSCHAN', 'AZERBAIYÁN', 'أذربيجان'],
  ),
  _CountryInfo(
    'KZ',
    ['KZ'],
    ['KAZAKHSTAN', 'KASACHSTAN', 'KAZAJISTÁN', 'كازاخستان'],
  ),
  _CountryInfo(
    'UZ',
    ['UZ'],
    ['UZBEKISTAN', 'OUZBÉKISTAN', 'USBEKISTAN', 'UZBEKISTÁN', 'أوزبكستان'],
  ),
  _CountryInfo('KW', ['KW'], ['KUWAIT', 'KOWEÏT', 'الكويت']),
  _CountryInfo('QA', ['QA'], ['QATAR', 'KATAR', 'CATAR', 'قطر']),
  _CountryInfo('BH', ['BH'], ['BAHRAIN', 'BAHREÏN', 'BARÉIN', 'البحرين']),
  _CountryInfo('OM', [], ['OMAN', 'OMÁN', 'عمان']),
  _CountryInfo('YE', ['YE'], ['YEMEN', 'YÉMEN', 'JEMEN', 'اليمن']),
  _CountryInfo(
    'JO',
    ['JO'],
    ['JORDAN', 'JORDANIE', 'JORDANIEN', 'JORDANIA', 'الأردن'],
  ),
  _CountryInfo('SY', ['SY'], ['SYRIA', 'SYRIE', 'SYRIEN', 'SIRIA', 'سوريا']),
  _CountryInfo('PS', [], ['PALESTINE', 'PALÄSTINA', 'PALESTINA', 'فلسطين']),
  _CountryInfo('IL', [], ['ISRAEL', 'ISRAËL', 'إسرائيل']),
  _CountryInfo('IR', ['IR'], ['IRAN', 'IRÁN', 'إيران', 'PERSIAN']),
  _CountryInfo('AF', ['AFG'], ['AFGHANISTAN', 'AFGANISTÁN', 'أفغانستان']),
  _CountryInfo('LY', ['LY'], ['LIBYA', 'LIBYE', 'LIBYEN', 'LIBIA', 'ليبيا']),
  _CountryInfo('SD', [], ['SUDAN', 'SOUDAN', 'SUDÁN', 'السودان']),
  _CountryInfo('MR', [], [
    'MAURITANIA',
    'MAURITANIE',
    'MAURETANIEN',
    'موريتانيا',
  ]),
  _CountryInfo('SN', ['SN'], ['SENEGAL', 'SÉNÉGAL', 'السنغال']),
  _CountryInfo(
    'CI',
    ['CI'],
    [
      'IVORY COAST',
      'CÔTE D\'IVOIRE',
      'ELFENBEINKÜSTE',
      'COSTA DE MARFIL',
      'ساحل العاج',
      'COTE D IVOIRE',
      'COTE IVOIRE',
    ],
  ),
  _CountryInfo('ML', ['ML'], ['MALI', 'MALÍ', 'مالي']),
  _CountryInfo('BF', ['BF'], ['BURKINA FASO', 'بوركينا فاسو', 'BURKINA']),
  _CountryInfo('NE', [], ['NIGER', 'NÍGER', 'النيجر']),
  _CountryInfo('NG', ['NG'], ['NIGERIA', 'نيجيريا', 'NIGÉRIA']),
  _CountryInfo('GH', ['GH'], ['GHANA', 'غانا']),
  _CountryInfo(
    'CM',
    ['CM'],
    ['CAMEROON', 'CAMEROUN', 'KAMERUN', 'CAMERÚN', 'الكاميرون'],
  ),
  _CountryInfo('GA', ['GA'], ['GABON', 'GABUN', 'GABÓN', 'الغابون']),
  _CountryInfo(
    'CG',
    ['CG'],
    ['CONGO', 'KONGO', 'الكونغو', 'CONGO BRAZZAVILLE'],
  ),
  _CountryInfo('CD', [], [
    'DR CONGO',
    'RD CONGO',
    'DR KONGO',
    'RD DEL CONGO',
    'الكونغو الديمقراطية',
    'RDC',
    'CONGO KINSHASA',
    'DRC',
  ]),
  _CountryInfo('BJ', ['BJ'], ['BENIN', 'BÉNIN', 'BENÍN', 'بنين']),
  _CountryInfo('TG', ['TG'], ['TOGO', 'توغو']),
  _CountryInfo('GN', ['GN'], ['GUINEA', 'GUINÉE', 'غينيا']),
  _CountryInfo(
    'GW',
    ['GW'],
    [
      'GUINEA-BISSAU',
      'GUINÉE-BISSAU',
      'GUINEA-BISÁU',
      'غينيا بيساو',
      'GUINEE BISSAU',
      'GUINEA BISSAU',
    ],
  ),
  _CountryInfo('SL', ['SL'], ['SIERRA LEONE', 'SIERRA LEONA', 'سيراليون']),
  _CountryInfo('LR', ['LR'], ['LIBERIA', 'ليبيريا']),
  _CountryInfo('GM', ['GM'], ['GAMBIA', 'GAMBIE', 'غامبيا']),
  _CountryInfo(
    'CV',
    ['CV'],
    [
      'CAPE VERDE',
      'CAP-VERT',
      'KAP VERDE',
      'CABO VERDE',
      'الرأس الأخضر',
      'CAP VERT',
    ],
  ),
  _CountryInfo(
    'ET',
    ['ET'],
    ['ETHIOPIA', 'ÉTHIOPIE', 'ÄTHIOPIEN', 'ETIOPÍA', 'إثيوبيا'],
  ),
  _CountryInfo('ER', ['ER'], ['ERITREA', 'ÉRYTHRÉE', 'إريتريا']),
  _CountryInfo('DJ', [], ['DJIBOUTI', 'DSCHIBUTI', 'YIBUTI', 'جيبوتي']),
  _CountryInfo('SO', [], ['SOMALIA', 'SOMALIE', 'الصومال']),
  _CountryInfo('KE', ['KE'], ['KENYA', 'KENIA', 'كينيا']),
  _CountryInfo('UG', ['UG'], ['UGANDA', 'OUGANDA', 'أوغندا']),
  _CountryInfo('TZ', ['TZ'], ['TANZANIA', 'TANZANIE', 'TANSANIA', 'تنزانيا']),
  _CountryInfo('RW', ['RW'], ['RWANDA', 'RUANDA', 'رواندا']),
  _CountryInfo('BI', ['BI'], ['BURUNDI', 'بوروندي']),
  _CountryInfo('AO', ['AO'], ['ANGOLA', 'أنغولا']),
  _CountryInfo('MZ', ['MZ'], ['MOZAMBIQUE', 'MOSAMBIK', 'موزمبيق']),
  _CountryInfo('ZM', ['ZM'], ['ZAMBIA', 'ZAMBIE', 'SAMBIA', 'زامبيا']),
  _CountryInfo('ZW', ['ZW'], ['ZIMBABWE', 'SIMBABWE', 'ZIMBABUE', 'زيمبابوي']),
  _CountryInfo('MW', ['MW'], ['MALAWI', 'MALAUI', 'ملاوي']),
  _CountryInfo('MG', ['MG'], ['MADAGASCAR', 'MADAGASKAR', 'مدغشقر']),
  _CountryInfo('MU', ['MU'], ['MAURITIUS', 'موريشيوس', 'ILE MAURICE']),
  _CountryInfo(
    'KM',
    ['KM'],
    ['COMOROS', 'COMORES', 'KOMOREN', 'COMORAS', 'جزر القمر'],
  ),
  _CountryInfo('NA', [], ['NAMIBIA', 'NAMIBIE', 'ناميبيا']),
  _CountryInfo('BW', ['BW'], ['BOTSWANA', 'BOTSUANA', 'بوتسوانا']),
  _CountryInfo('TD', ['TD'], ['CHAD', 'TCHAD', 'TSCHAD', 'تشاد']),
  _CountryInfo(
    'CF',
    ['CF'],
    [
      'CENTRAL AFRICAN REPUBLIC',
      'CENTRAFRIQUE',
      'ZENTRALAFRIKANISCHE REPUBLIK',
      'REPÚBLICA CENTROAFRICANA',
      'أفريقيا الوسطى',
    ],
  ),
  _CountryInfo(
    'SS',
    ['SS'],
    [
      'SOUTH SUDAN',
      'SOUDAN DU SUD',
      'SÜDSUDAN',
      'SUDÁN DEL SUR',
      'جنوب السودان',
    ],
  ),
  _CountryInfo(
    'GQ',
    ['GQ'],
    [
      'EQUATORIAL GUINEA',
      'GUINÉE ÉQUATORIALE',
      'ÄQUATORIALGUINEA',
      'GUINEA ECUATORIAL',
      'غينيا الاستوائية',
    ],
  ),
  _CountryInfo('SC', ['SC'], ['SEYCHELLES', 'SEYCHELLEN', 'سيشل']),
  _CountryInfo(
    'CO',
    ['COL'],
    ['COLOMBIA', 'COLOMBIE', 'KOLUMBIEN', 'كولومبيا'],
  ),
  _CountryInfo('PE', ['PE'], ['PERU', 'PÉROU', 'PERÚ', 'بيرو']),
  _CountryInfo('VE', ['VE'], ['VENEZUELA', 'فنزويلا']),
  _CountryInfo('CL', ['CL'], ['CHILE', 'CHILI', 'تشيلي']),
  _CountryInfo('EC', ['EC'], ['ECUADOR', 'ÉQUATEUR', 'الإكوادور']),
  _CountryInfo('BO', ['BO'], ['BOLIVIA', 'BOLIVIE', 'BOLIVIEN', 'بوليفيا']),
  _CountryInfo('PY', ['PY'], ['PARAGUAY', 'باراغواي']),
  _CountryInfo('UY', ['UY'], ['URUGUAY', 'الأوروغواي']),
  _CountryInfo('CU', ['CU'], ['CUBA', 'KUBA', 'كوبا']),
  _CountryInfo('DO', [], [
    'DOMINICAN REPUBLIC',
    'RÉPUBLIQUE DOMINICAINE',
    'DOMINIKANISCHE REPUBLIK',
    'REPÚBLICA DOMINICANA',
    'جمهورية الدومينيكان',
    'REPUBLIQUE DOMINICAINE',
    'DOMINICANA',
  ]),
  _CountryInfo('HT', ['HT'], ['HAITI', 'HAÏTI', 'HAITÍ', 'هايتي']),
  _CountryInfo('JM', ['JM'], ['JAMAICA', 'JAMAÏQUE', 'JAMAIKA', 'جامايكا']),
  _CountryInfo('PR', ['PR'], ['PUERTO RICO', 'PORTO RICO', 'بورتوريكو']),
  _CountryInfo('GT', ['GT'], ['GUATEMALA', 'غواتيمالا']),
  _CountryInfo('HN', ['HN'], ['HONDURAS', 'هندوراس']),
  _CountryInfo('SV', ['SV'], ['EL SALVADOR', 'SALVADOR', 'السلفادور']),
  _CountryInfo('NI', ['NI'], ['NICARAGUA', 'نيكاراغوا']),
  _CountryInfo('CR', ['CR'], ['COSTA RICA', 'كوستاريكا']),
  _CountryInfo('PA', ['PA'], ['PANAMA', 'PANAMÁ', 'بنما']),
  _CountryInfo(
    'TT',
    ['TT'],
    [
      'TRINIDAD AND TOBAGO',
      'TRINITÉ-ET-TOBAGO',
      'TRINIDAD UND TOBAGO',
      'TRINIDAD Y TOBAGO',
      'ترينيداد وتوباغو',
      'TRINIDAD',
    ],
  ),
  _CountryInfo('TH', ['TH'], ['THAILAND', 'THAÏLANDE', 'TAILANDIA', 'تايلاند']),
  _CountryInfo('VN', ['VN'], ['VIETNAM', 'VIÊT NAM', 'فيتنام']),
  _CountryInfo(
    'PH',
    ['PH'],
    ['PHILIPPINES', 'PHILIPPINEN', 'FILIPINAS', 'الفلبين'],
  ),
  _CountryInfo('ID', [], ['INDONESIA', 'INDONÉSIE', 'INDONESIEN', 'إندونيسيا']),
  _CountryInfo('MY', [], ['MALAYSIA', 'MALAISIE', 'MALASIA', 'ماليزيا']),
  _CountryInfo(
    'SG',
    ['SG'],
    ['SINGAPORE', 'SINGAPOUR', 'SINGAPUR', 'سنغافورة'],
  ),
  _CountryInfo(
    'BD',
    ['BD'],
    ['BANGLADESH', 'BANGLADESCH', 'BANGLADÉS', 'بنغلاديش'],
  ),
  _CountryInfo('LK', ['LK'], ['SRI LANKA', 'سريلانكا']),
  _CountryInfo('NP', ['NP'], ['NEPAL', 'NÉPAL', 'نيبال']),
  _CountryInfo('TW', ['TW'], ['TAIWAN', 'TAÏWAN', 'TAIWÁN', 'تايوان']),
  _CountryInfo('HK', ['HK'], ['HONG KONG', 'HONGKONG', 'هونغ كونغ']),
  _CountryInfo(
    'KH',
    ['KH'],
    ['CAMBODIA', 'CAMBODGE', 'KAMBODSCHA', 'CAMBOYA', 'كمبوديا'],
  ),
  _CountryInfo('MM', ['MM'], ['MYANMAR', 'BIRMANIE', 'BIRMANIA', 'ميانمار']),
  _CountryInfo(
    'NZ',
    ['NZ'],
    [
      'NEW ZEALAND',
      'NOUVELLE-ZÉLANDE',
      'NEUSEELAND',
      'NUEVA ZELANDA',
      'نيوزيلندا',
    ],
  ),
  _CountryInfo('ARB', ['AR', 'ARA', 'ARAB'], ['ARABIC', 'ARABE', 'ARAB']),
  _CountryInfo('AFR', ['AF', 'AFR'], ['AFRICA', 'AFRIQUE']),
  _CountryInfo('LAT', ['LAT'], ['LATIN AMERICA', 'LATINO', 'LATAM', 'LATINA']),
  _CountryInfo('EXYU', ['EXYU'], ['EX YU', 'EX-YU', 'EXYU']),
];

final Map<String, String> _byPrefix = {
  for (final country in _countries)
    for (final prefix in country.prefixes) prefix: country.code,
};

final Map<String, String> _byFoldedName = {
  for (final country in _countries)
    for (final name in country.names)
      lowerWithoutDiacritics(name): country.code,
};

/// Noms avec et sans accents, triés du plus long au plus court : « AFRIQUE DU
/// SUD » doit l'emporter sur « AFRIQUE ».
final RegExp _namePattern = () {
  final names = <String>{
    for (final country in _countries)
      for (final name in country.names) ...[name, lowerWithoutDiacritics(name)],
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    '(?<![\\p{L}\\p{N}])(?:${names.map(RegExp.escape).join('|')})'
    '(?![\\p{L}\\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
}();

/// Identifiant iptv-org ou XMLTV : `TF1.fr`, `BBCOne.uk`, `TF1.fr@SD`.
final RegExp _tvgIdSuffix = RegExp(
  r'\.([a-z]{2})(?:@\w+)?$',
  caseSensitive: false,
);

/// Pseudo-codes des régions : les chaînes de ces groupes se répartissent par
/// pays d'après leurs propres indices.
const Set<String> _regions = {'ARB', 'AFR', 'LAT', 'EXYU'};

/// Dictionnaire des pays présents dans les playlists.
abstract final class CountryCatalog {
  /// Vrai pour un pseudo-code de région, comme `AFR` pour « Afrique ».
  static bool isRegion(String code) => _regions.contains(code);

  /// Retourne le code du préfixe [token], par exemple `UK` donne `GB`.
  static String? fromPrefix(String token) => _byPrefix[token.toUpperCase()];

  /// Cherche un nom de pays dans [text], par exemple dans un `group-title`.
  /// Un pays l'emporte sur une région : « AFRIQUE - TUNISIE » donne la
  /// Tunisie.
  static String? fromText(String text) {
    String? region;
    for (final match in _namePattern.allMatches(text)) {
      final code = _byFoldedName[lowerWithoutDiacritics(match[0]!)];
      if (code == null) continue;
      if (!isRegion(code)) return code;
      region ??= code;
    }
    return region;
  }

  /// Déduit le pays d'un identifiant de guide.
  ///
  /// Ces identifiants suivent les codes ISO : `.ar` y désigne l'Argentine.
  static String? fromTvgId(String tvgId) {
    final match = _tvgIdSuffix.firstMatch(tvgId);
    if (match == null) return null;
    final code = match[1]!.toUpperCase();
    return code == 'AR' ? 'AR' : fromPrefix(code);
  }

  /// Retire de [text] les noms de pays. « FRANCE SPORT » devient « SPORT ».
  static String removeNames(String text) => text.replaceAll(_namePattern, ' ');
}
