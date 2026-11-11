import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

import '../http_text_stream.dart';
import 'json_array_stream.dart';
import 'xtream_dtos.dart';

/// Statuts d'un serveur réellement en panne, Cloudflare compris.
const Set<int> _outageStatuses = {
  500,
  502,
  503,
  504,
  520,
  521,
  522,
  523,
  524,
  525,
  526,
  527,
  530,
};

/// Client de l'API Xtream Codes.
final class XtreamApiClient {
  const XtreamApiClient(this._client, this._credentials);

  final http.Client _client;
  final XtreamCredentials _credentials;

  /// Vérifie le compte. `auth` vaut 0 si les identifiants sont refusés.
  ///
  /// Certains panneaux refusent plutôt par un statut HTTP de leur invention,
  /// comme 511 ou 513 : à la connexion, seule une vraie panne n'est pas un refus.
  Future<void> authenticate() async {
    final Object? json;
    try {
      json = await _getJson(_apiUri());
    } on ServerFailure catch (failure) {
      if (_outageStatuses.contains(failure.status)) rethrow;
      throw AuthFailure(
        'Compte Xtream refusé (HTTP ${failure.status}).',
        status: failure.status,
      );
    }
    final userInfo = json is Map<String, dynamic> ? json['user_info'] : null;
    if (userInfo is! Map<String, dynamic> || readInt(userInfo['auth']) != 1) {
      throw const AuthFailure('Compte Xtream refusé.');
    }
  }

  /// Retourne les catégories, indexées par identifiant.
  Future<Map<String, String>> categories(String action) async {
    final categories = await objects(
      action,
    ).map(XtreamCategory.fromJson).toList();
    return {for (final category in categories) category.id: category.name};
  }

  /// Lit une liste en flux, sans charger la réponse complète.
  Stream<Map<String, dynamic>> objects(String action) async* {
    final response = await openGet(
      _client,
      _apiUri({'action': action}),
      timeout: catalogResponseTimeout,
    );
    try {
      // Pas de `yield*` : il transmettrait les erreurs du décodeur telles
      // quelles, sans passer par les `on` ci-dessous.
      await for (final object in decodeJsonObjects(textChunks(response))) {
        yield object;
      }
    } on TruncatedJsonException {
      throw const NetworkFailure('Réponse Xtream interrompue.');
    } on FormatException {
      throw const ParseFailure('Réponse Xtream illisible.');
    }
  }

  /// Retourne les épisodes d'une série.
  Future<List<XtreamEpisode>> seriesEpisodes(int seriesId) async {
    final json = await _getJson(
      _apiUri({'action': 'get_series_info', 'series_id': '$seriesId'}),
    );
    if (json is! Map<String, dynamic>) return const [];
    return XtreamEpisode.listFromSeriesInfo(json);
  }

  /// Adresse du guide XMLTV du compte.
  Uri get xmltvUri => _uriFor('xmltv.php');

  Uri _apiUri([Map<String, String> extra = const {}]) =>
      _uriFor('player_api.php', extra);

  Uri _uriFor(String script, [Map<String, String> extra = const {}]) {
    try {
      final server = ResolveStreamUrl.normalizeXtreamServer(
        _credentials.serverUrl,
      );
      return Uri.parse('$server/$script').replace(
        queryParameters: {
          'username': _credentials.username,
          'password': _credentials.password,
          ...extra,
        },
      );
    } on FormatException {
      throw const NetworkFailure('Adresse du serveur invalide.');
    }
  }

  Future<Object?> _getJson(Uri uri) async {
    final response = await openGet(_client, uri);
    final buffer = StringBuffer();
    await textChunks(response).forEach(buffer.write);
    try {
      return jsonDecode(buffer.toString());
    } on FormatException {
      throw const ParseFailure('Réponse Xtream illisible.');
    }
  }
}
