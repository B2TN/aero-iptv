import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';

/// Délai au-delà duquel GitHub est tenu pour injoignable : la vérification
/// se refait plus tard, sans gêner l'utilisateur.
const Duration _timeout = Duration(seconds: 15);

/// Releases du dépôt public de l'application sur GitHub.
///
/// L'API publique se passe de compte. Rien de l'utilisateur ne part : la
/// requête ne porte que le nom du dépôt et un agent générique.
final class GithubReleaseRepository implements ReleaseRepository {
  const GithubReleaseRepository(
    this._client, {
    this.repository = 'B2TN/aero-iptv',
  });

  final http.Client _client;

  /// `propriétaire/dépôt`.
  final String repository;

  @override
  Future<List<AppRelease>> releases() async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.https('api.github.com', '/repos/$repository/releases', {
              'per_page': '20',
            }),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'AeroIPTV',
            },
          )
          .timeout(_timeout);
    } on SocketException catch (error) {
      throw NetworkFailure('GitHub injoignable : ${error.message}');
    } on TimeoutException {
      throw const NetworkFailure('GitHub ne répond pas.');
    } on http.ClientException catch (error) {
      throw NetworkFailure('GitHub injoignable : ${error.message}');
    }
    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.tooManyRequests) {
      throw const RateLimitFailure('Limite de l API GitHub atteinte.');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw ServerFailure(
        'Réponse inattendue de GitHub.',
        status: response.statusCode,
      );
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ParseFailure('Réponse GitHub illisible.');
    }
    if (json is! List) throw const ParseFailure('Liste de releases attendue.');
    return [
      for (final item in json)
        if (item is Map<String, dynamic>) ?_release(item),
    ];
  }

  AppRelease? _release(Map<String, dynamic> json) {
    if (json['draft'] == true) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = AppVersion.tryParse(tag);
    if (version == null) return null;
    final assets = json['assets'];
    return AppRelease(
      version: version,
      tag: tag,
      preRelease: json['prerelease'] == true || version.isPreRelease,
      notes: json['body'] is String ? json['body'] as String : '',
      pageUrl: json['html_url'] is String ? json['html_url'] as String : '',
      assets: {
        if (assets is List)
          for (final asset in assets)
            if (asset is Map<String, dynamic> &&
                asset['name'] is String &&
                asset['browser_download_url'] is String)
              asset['name'] as String: ReleaseAsset(
                url: asset['browser_download_url'] as String,
                size: asset['size'] is int ? asset['size'] as int : 0,
              ),
      },
    );
  }
}
