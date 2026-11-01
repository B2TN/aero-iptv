import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../adapters/http_text_stream.dart';

const String _host = 'itunes.apple.com';
const String _fallbackCountry = 'us';
const int _chartSize = 100;

/// L'accueil attend cette réponse : un service lent ne doit pas le bloquer.
const Duration _timeout = Duration(seconds: 8);
const Duration _cacheDuration = Duration(minutes: 30);

/// Saison et mention de langue ajoutées au titre : « Dexter, Saison 1 (VF) ».
final RegExp _seasonSuffix = RegExp(
  r'[,:\s–-]*\b(?:saison|season|staffel|temporada|stagione)\s*\d+.*$',
  caseSensitive: false,
);
final RegExp _languageSuffix = RegExp(
  r'\s*\((?:VF|VOST|VOSTF|VM|VO|VFQ)\)\s*$',
  caseSensitive: false,
);

/// Classements publics d'Apple, utilisables sans compte ni clé.
///
/// Ils reflètent les ventes et les locations du moment. L'accueil montre ainsi
/// des contenus populaires même sans jeton TMDb.
final class AppleChartsClient {
  AppleChartsClient(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, (DateTime, List<TrendingItem>)> _cache = {};

  /// Classement de [region], complété par celui des États-Unis : les catalogues
  /// mêlent titres traduits et titres originaux.
  Future<List<TrendingItem>> popular(ContentKind kind, {String? region}) async {
    final country = (region ?? _fallbackCountry).toLowerCase();
    final key = '${kind.name}/$country';
    final cached = _cache[key];
    if (cached != null && _clock().difference(cached.$1) < _cacheDuration) {
      return cached.$2;
    }
    final charts = await Future.wait([
      _chart(kind, country),
      if (country != _fallbackCountry) _chart(kind, _fallbackCountry),
    ]);
    final seen = <String>{};
    final items = [
      for (final item in charts.expand((chart) => chart))
        if (seen.add(GroupingKey.of(item.title))) item,
    ];
    _cache[key] = (_clock(), items);
    return items;
  }

  Future<List<TrendingItem>> _chart(ContentKind kind, String country) async {
    final isMovie = kind == ContentKind.movie;
    final chart = isMovie ? 'topmovies' : 'toptvseasons';
    final response = await openGet(
      _client,
      Uri.https(_host, '/$country/rss/$chart/limit=$_chartSize/json'),
      timeout: _timeout,
    );
    final Object? json;
    try {
      json = jsonDecode(await textChunks(response).join());
    } on FormatException {
      throw const ParseFailure('Classement Apple illisible.');
    }
    final feed = json is Map<String, dynamic> ? json['feed'] : null;
    final entries = feed is Map<String, dynamic> ? feed['entry'] : null;
    if (entries is! List) return const [];
    return [
      for (final entry in entries)
        if (entry is Map<String, dynamic>) ?_toItem(entry, kind),
    ];
  }

  TrendingItem? _toItem(Map<String, dynamic> entry, ContentKind kind) {
    final name = entry['im:name'];
    final label = name is Map<String, dynamic> ? name['label'] : null;
    if (label is! String) return null;
    final title = label
        .replaceFirst(_languageSuffix, '')
        .replaceFirst(_seasonSuffix, '')
        .trim();
    if (title.isEmpty) return null;
    return TrendingItem(kind: kind, title: title, originalTitle: title);
  }
}
