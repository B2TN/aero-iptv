import '../entities/content_kind.dart';
import '../entities/stream_quality.dart';
import 'country_catalog.dart';
import 'grouping_key.dart';
import 'language_parser.dart';
import 'quality_parser.dart';
import 'text_folding.dart';

/// Marqueur d'épisode : `S01E02`, `S1 E2`, `1x02`, `Saison 1 Épisode 2`.
final RegExp _episodeMarker = RegExp(
  r'\bS(?:aison|eason)?[\s._-]*(\d{1,3})[\s._,-]*E(?:p(?:isode)?)?[\s._-]*(\d{1,4})\b'
  r'|\b(\d{1,2})x(\d{2,3})\b'
  r'|\bS(?:aison|eason)\s*(\d{1,3})\s*[,–-]?\s*[ÉE]pisode\s*(\d{1,4})\b',
  caseSensitive: false,
);

/// Ligne de séparation déguisée en chaîne : `#### FRANCE ####`.
final RegExp _headerEntry = RegExp(r'^\W*[#=*~_-]{3,}');

/// Étiquette en tête de titre, entre délimiteurs ou suivie d'un séparateur.
final RegExp _leadingTag = RegExp(
  r'^[\s|]*(?:[\[({]\s*([^\])}]{1,20}?)\s*[\])}]|\|\s*([^|]{1,12}?)\s*\||'
  r'([\p{L}\p{N}+]{2,10}(?:-[\p{L}\p{N}]{2,3})?)\s*(?:[:|]|\s[-–—]\s))'
  r'[\s:|–—-]*',
  unicode: true,
);

/// Langue suivie de mentions techniques : `DE-BLURAY-DV - `, `IT-[4K] - `.
final RegExp _bouquetPrefix = RegExp(
  r'^\s*([A-Z]{2})-\s*\[?((?:4K|UHD|BLURAY|DV|HDR)(?:-(?:4K|UHD|BLURAY|DV|HDR))*)'
  r'\]?\s*-?\s+',
);

/// Pays d'origine en fin de titre de VOD, comme `(US)` : ce n'est pas la langue
/// de la version. « FR - Dexter (2006) (US) » est bien une version française.
final RegExp _originTag = RegExp(
  r'[\s:|–—-]*[\[(]\s*([A-Z]{2})\s*[\])][\s|]*$',
);

/// Mention de doublage ou de sous-titrage d'une version.
final RegExp _versionNote = RegExp(
  r'[\[(]\s*((?:ger |eng |multi )?sub|dub|svenskt tal|ai)\s*[\])]',
  caseSensitive: false,
);

/// Traduction collée après le titre latin : « Dexter: Resurrection دکستر ».
final RegExp _foreignTail = RegExp(r'^(.*[A-Za-z]{2}.*?)\s+[֐-ۿ].*$');

/// Mention commerciale placée sans séparateur : `VIP FR: TF1`.
final RegExp _leadingNoise = RegExp(
  r'^(?:VIP|PREMIUM|GOLD)\s+',
  caseSensitive: false,
);

/// Dernier mot du titre, éventuellement entre crochets ou parenthèses.
final RegExp _trailingTag = RegExp(
  r'[\s|:–—-]*(?:[\[({]\s*([^\])}]{1,20}?)\s*[\])}]|([\p{L}\p{N}+.]{2,12}))[\s|]*$',
  unicode: true,
);

final RegExp _bracketed = RegExp(r'[\[({]\s*([^\])}]{1,20}?)\s*[\])}]');
final RegExp _tagSeparator = RegExp(r'[\s/,+-]+');
final RegExp _bracketYear = RegExp(r'[\[({]((?:19|20)\d{2})[\])}]');
final RegExp _trailingYear = RegExp(r'[\s._-]+((?:19|20)\d{2})$');

/// Publicité insérée dans un titre : adresse, compte Telegram, signature.
///
/// `.tv` et `.live` ne sont retirés qu'avec `www.` ou un schéma, car ils font
/// partie de noms légitimes comme « Arte.tv ». Un simple « by » reste en place
/// pour ne pas amputer « Stand by Me ».
final RegExp _advert = RegExp(
  r'(?:https?://|www\.)\S+|[\w-]+\.(?:com|net|org|xyz|info|top|site)\b\S*'
  r'|\bt\.me/\S+|(?<!\w)@\w+|\bpowered by\s+\S+\s*$',
  caseSensitive: false,
);

final RegExp _spaces = RegExp(r'\s+');
final RegExp _edgeSeparators = RegExp(r'^[\s|:._–—-]+|[\s|:._–—-]+$');

/// Codecs et formats : retirés du titre, mais conservés pour le menu de flux.
const Set<String> _codecTags = {
  'HEVC',
  'H264',
  'H265',
  'H.264',
  'H.265',
  'X264',
  'X265',
  'AV1',
  'HDR',
  'HDR10',
  '10BIT',
  '50FPS',
  '60FPS',
};

/// Mentions commerciales et techniques à retirer.
const Set<String> _noiseTags = {
  'VIP',
  'PREMIUM',
  'GOLD',
  'BACKUP',
  'BK',
  'BKP',
  'ALT',
  'RAW',
  'GEO',
  'BLOCKED',
  'NEW',
};

/// Plateformes ajoutées en préfixe des titres de VOD.
const Set<String> _platformTags = {
  'NF',
  'AMZ',
  'DSNP',
  'HMAX',
  'ATVP',
  'PMTP',
  'PCOK',
  'HULU',
};

/// Sous-ensemble de [_noiseTags] reconnu sans crochets en fin de titre.
const Set<String> _strongNoiseTags = {'VIP', 'PREMIUM', 'BACKUP'};

/// Préfixes de VOD relevés sur de vrais catalogues, en plus des langues et des
/// pays connus. Une liste plutôt qu'une règle générale : « CSI - Miami » et
/// « FBI - Most Wanted » commencent aussi par un sigle.
const Set<String> _vodPrefixes = {
  'AF',
  'BG',
  'BN',
  'BR',
  'DK',
  'EX',
  'FI',
  'HU',
  'IN',
  'IND',
  'IR',
  'ISR',
  'KN',
  'ML',
  'MR',
  'NO',
  'PB',
  'PH',
  'PK',
  'QFR',
  'RO',
  'SC',
  'SE',
  'SOM',
  'TL',
  'TM',
  'UR',
};

/// Résultat de l'analyse d'un nom de chaîne, de film ou d'épisode.
final class ParsedTitle {
  const ParsedTitle({
    required this.title,
    this.quality = StreamQuality.unknown,
    this.codecTags = const [],
    this.language,
    this.countryCode,
    this.year,
    this.season,
    this.episode,
    this.episodeTitle,
    this.versionLabel,
  });

  /// Nom débarrassé des préfixes, suffixes et mentions publicitaires.
  final String title;
  final StreamQuality quality;
  final List<String> codecTags;
  final String? language;

  /// Pays indiqué par une étiquette du nom.
  final String? countryCode;
  final int? year;
  final int? season;
  final int? episode;

  /// Texte placé après le marqueur d'épisode.
  final String? episodeTitle;

  /// Libellé de la version tel que le fournisseur l'écrit : « 4K-SC », « DE SUB ».
  final String? versionLabel;

  /// Libellé du flux dans le menu de choix, par exemple « FHD HEVC ».
  String get variantLabel => [
    if (quality != StreamQuality.unknown) quality.label,
    ...codecTags,
  ].join(' ');
}

/// Résultat de l'analyse d'un nom de groupe.
final class ParsedGroup {
  const ParsedGroup({
    required this.displayName,
    required this.key,
    this.countryCode,
    this.language,
  });

  /// Nom sans pays ni qualité. Vide pour un groupe comme « FRANCE FHD ».
  final String displayName;
  final String key;
  final String? countryCode;

  /// Langue du groupe, utile quand le titre n'en indique aucune.
  final String? language;
}

/// Accumule les informations extraites des étiquettes.
final class _Tags {
  StreamQuality quality = StreamQuality.unknown;
  final Set<String> codecs = {};
  String? language;
  String? country;

  /// Premier préfixe du titre, gardé tel quel pour nommer la version.
  String? prefix;
  String? note;

  /// Libellé de la version, ou `null` si le titre n'en indique aucune.
  String? get versionLabel {
    final parts = [?prefix, ?note];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Consomme un préfixe, éventuellement composé comme `4K-SC`.
  bool acceptPrefix(String token, {required bool vod}) {
    final parts = token.split('-');
    final known = parts.every(
      (part) =>
          (vod && _vodPrefixes.contains(part.toUpperCase())) ||
          _Tags().accept(part, strongOnly: false),
    );
    if (!known) return false;
    for (final part in parts) {
      accept(part, strongOnly: false);
    }
    return true;
  }

  /// Tente de consommer [token]. [strongOnly] refuse les codes ambigus.
  bool accept(String token, {required bool strongOnly}) {
    final upper = token.toUpperCase();
    final parsedQuality = QualityParser.fromToken(upper);
    if (parsedQuality != StreamQuality.unknown) {
      if (parsedQuality.index > quality.index) quality = parsedQuality;
      return true;
    }
    if (_codecTags.contains(upper)) {
      codecs.add(upper);
      return true;
    }
    if (strongOnly) {
      if (_strongNoiseTags.contains(upper)) return true;
      final language = LanguageParser.fromStrongToken(token);
      if (language != null) this.language ??= language;
      return language != null;
    }
    if (_noiseTags.contains(upper) || _platformTags.contains(upper)) {
      return true;
    }
    final language = LanguageParser.fromToken(upper);
    final country = CountryCatalog.fromPrefix(upper);
    if (language != null) this.language ??= language;
    if (country != null) this.country ??= country;
    return language != null || country != null;
  }

  /// Une parenthèse comme `(FR HEVC)` n'est retirée que si tous ses mots sont
  /// reconnus : `(East)` et `(Directors Cut)` restent dans le titre.
  bool acceptAll(String content) {
    final tokens = content.split(_tagSeparator).where((t) => t.isNotEmpty);
    final preview = _Tags();
    if (tokens.isEmpty ||
        !tokens.every((t) => preview.accept(t, strongOnly: false))) {
      return false;
    }
    for (final token in tokens) {
      accept(token, strongOnly: false);
    }
    return true;
  }
}

/// Nettoie les noms fournis par les fournisseurs IPTV.
final class TitleCleaner {
  const TitleCleaner();

  /// Indique si [raw] est une ligne de séparation et non un vrai contenu.
  bool isHeaderEntry(String raw) => _headerEntry.hasMatch(foldDecorations(raw));

  /// Indique si [raw] contient un marqueur d'épisode.
  bool hasEpisodeMarker(String raw) => _episodeMarker.hasMatch(raw);

  /// Retourne le nom de la série d'origine, sans le marqueur d'épisode.
  String seriesNameOf(String raw) {
    final marker = _episodeMarker.firstMatch(raw);
    return marker == null ? raw : raw.substring(0, marker.start).trim();
  }

  /// Analyse un nom de [kind]. Le titre retourné n'est jamais vide : si le
  /// nettoyage retire tout, comme pour une chaîne appelée « 4K », le nom
  /// d'origine est conservé.
  /// Ramène ces préfixes à la forme connue : `DE - `, ou `4K-DE - ` en 4K.
  String _simplifyBouquetPrefix(String text) => text.replaceFirstMapped(
    _bouquetPrefix,
    (match) => '${match[2]!.contains('4K') ? '4K-' : ''}${match[1]} - ',
  );

  ParsedTitle parse(String raw, ContentKind kind) {
    final folded = foldDecorations(raw);
    final tags = _Tags();
    var text = folded.replaceAll(_advert, ' ');
    int? season;
    int? episode;
    String? tail;
    int? year;

    if (kind != ContentKind.live) {
      final marker = _episodeMarker.firstMatch(text);
      if (marker != null) {
        season = int.parse(marker[1] ?? marker[3] ?? marker[5]!);
        episode = int.parse(marker[2] ?? marker[4] ?? marker[6]!);
        tail = text.substring(marker.end);
        text = text.substring(0, marker.start);
      }
      final bracketYear = _bracketYear.firstMatch(text);
      if (bracketYear != null) {
        year = int.parse(bracketYear[1]!);
        text = text.replaceRange(bracketYear.start, bracketYear.end, ' ');
      }
    }

    final vod = kind != ContentKind.live;
    if (vod) text = _simplifyBouquetPrefix(text);
    // Le préfixe passe d'abord : il dit la langue de la version, alors qu'une
    // parenthèse finale comme `(US)` ne dit que le pays d'origine.
    text = _stripLeading(text, tags, vod: vod);
    if (vod) text = _stripOrigin(_stripVersionNotes(text, tags), tags);
    text = _stripEdges(_stripBrackets(text, tags), tags);

    if (kind != ContentKind.live && year == null) {
      final trailingYear = _trailingYear.firstMatch(text);
      final parsedYear = int.tryParse(trailingYear?[1] ?? '');
      // Une année future fait partie du titre : « Blade Runner 2049 ».
      if (parsedYear != null && parsedYear <= DateTime.now().year + 1) {
        year = parsedYear;
        text = _stripEdges(text.substring(0, trailingYear!.start), tags);
      }
    }

    // Lu avant de construire le résultat : la fin du titre peut compléter tags.
    final episodeTitle = tail == null ? null : _parseTail(tail, tags);
    final tidied = _tidy(text);
    final title = vod
        ? tidied.replaceFirstMapped(_foreignTail, (match) => match[1]!)
        : tidied;
    return ParsedTitle(
      title: title.isEmpty ? _tidy(folded) : title,
      quality: tags.quality,
      codecTags: tags.codecs.toList(growable: false),
      language: tags.language,
      countryCode: tags.country,
      year: year,
      season: season,
      episode: episode,
      episodeTitle: episodeTitle,
      versionLabel: tags.versionLabel,
    );
  }

  String _stripVersionNotes(String text, _Tags tags) =>
      text.replaceAllMapped(_versionNote, (match) {
        final note = match[1]!.toLowerCase();
        tags.note ??= note.contains('sub')
            ? 'SUB'
            : note == 'ai'
            ? 'AI'
            : 'DUB';
        return ' ';
      });

  /// Sans préfixe, le pays d'origine reste le seul indice sur la langue.
  String _stripOrigin(String input, _Tags tags) {
    var text = input;
    while (true) {
      final match = _originTag.firstMatch(text);
      if (match == null) return text;
      if (tags.prefix == null) tags.accept(match[1]!, strongOnly: false);
      text = text.substring(0, match.start);
    }
  }

  /// Analyse un `group-title`.
  ParsedGroup parseGroup(String raw) {
    final tags = _Tags();
    final folded = foldDecorations(raw).replaceAll(_advert, ' ');
    final country = CountryCatalog.fromText(folded);
    final text = _stripEdges(_stripBrackets(folded, tags), tags);
    final displayName = _tidy(
      _stripTrailing(
        CountryCatalog.removeNames(text),
        tags,
        allowEmpty: true,
        allowShortCodes: true,
      ),
    );
    return ParsedGroup(
      displayName: displayName,
      key: GroupingKey.of(displayName),
      countryCode: tags.country ?? country,
      language: tags.language,
    );
  }

  /// Retire les étiquettes entre crochets situées n'importe où.
  String _stripBrackets(String text, _Tags tags) => text.replaceAllMapped(
    _bracketed,
    (match) => tags.acceptAll(match[1]!) ? ' ' : match[0]!,
  );

  String _stripEdges(String text, _Tags tags, {bool allowEmpty = false}) =>
      _stripTrailing(_stripLeading(text, tags), tags, allowEmpty: allowEmpty);

  String _stripLeading(String input, _Tags tags, {bool vod = false}) {
    var text = input.trim();
    while (true) {
      final noise = _leadingNoise.firstMatch(text);
      if (noise != null) {
        text = text.substring(noise.end);
        continue;
      }
      final match = _leadingTag.firstMatch(text);
      if (match == null) return text;
      final bracketed = match[1] ?? match[2];
      final bareToken = match[3];
      // Un préfixe nu doit être en majuscules : « It: Chapter Two » est un
      // titre, pas une étiquette italienne.
      final accepted = bracketed != null
          ? tags.acceptAll(bracketed) || tags.acceptPrefix(bracketed, vod: vod)
          : bareToken == bareToken!.toUpperCase() &&
                tags.acceptPrefix(bareToken, vod: vod);
      if (!accepted) return text;
      tags.prefix ??= (bracketed ?? bareToken)!.toUpperCase();
      text = text.substring(match.end);
    }
  }

  /// [allowShortCodes] accepte les codes de langue nus en majuscules. Il est
  /// réservé aux groupes, où « SERIES FR » ne peut pas être un titre.
  String _stripTrailing(
    String input,
    _Tags tags, {
    bool allowEmpty = false,
    bool allowShortCodes = false,
  }) {
    var text = input.trim();
    while (true) {
      final match = _trailingTag.firstMatch(text);
      if (match == null) return text;
      final remaining = text.substring(0, match.start).trim();
      if (remaining.isEmpty && !allowEmpty) return text;
      final bracketed = match[1];
      final bareToken = match[2];
      final accepted = bracketed != null
          ? tags.acceptAll(bracketed)
          : allowShortCodes && bareToken == bareToken!.toUpperCase()
          ? tags.accept(bareToken, strongOnly: false)
          : tags.accept(bareToken!, strongOnly: true);
      if (!accepted) return text;
      text = remaining;
    }
  }

  /// Extrait les étiquettes situées après le marqueur d'épisode.
  String? _parseTail(String tail, _Tags tags) {
    final title = _tidy(
      _stripEdges(_stripBrackets(tail, tags), tags, allowEmpty: true),
    );
    return title.isEmpty ? null : title;
  }

  String _tidy(String text) =>
      text.replaceAll(_spaces, ' ').replaceAll(_edgeSeparators, '');
}
