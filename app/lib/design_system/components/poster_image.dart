import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../app/di/infrastructure_providers.dart';
import '../tokens/aero_tokens.dart';

const int _maxCachedFiles = 1500;
const Duration _downloadTimeout = Duration(seconds: 12);

/// Cache disque des affiches : les sticks ont peu de mémoire et un réseau lent.
final class PosterCache {
  PosterCache(this._directory, this._client);

  final Directory _directory;
  final http.Client _client;
  final Set<String> _failed = {};

  /// Retourne l'image, depuis le disque si possible.
  Future<Uint8List> fetch(String url) async {
    if (_failed.contains(url)) throw StateError('Image indisponible.');
    final file = File(p.join(_directory.path, _fileName(url)));
    if (file.existsSync()) return file.readAsBytes();
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_downloadTimeout);
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('Image indisponible.');
      }
      await file.writeAsBytes(response.bodyBytes, flush: false);
      return response.bodyBytes;
    } on Object {
      // Un logo cassé ne doit pas être redemandé à chaque défilement.
      _failed.add(url);
      rethrow;
    }
  }

  /// Supprime les fichiers les plus anciens au-delà de la limite.
  Future<void> trim() async {
    final files = _directory.listSync().whereType<File>().toList();
    if (files.length <= _maxCachedFiles) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files.take(files.length - _maxCachedFiles)) {
      await file.delete();
    }
  }

  /// Empreinte FNV-1a : assez courte pour un nom de fichier.
  String _fileName(String url) {
    var hash = 0xcbf29ce484222325;
    for (final unit in url.codeUnits) {
      hash = (hash ^ unit) * 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16);
  }
}

/// Fournisseur d'image lié au cache disque.
@immutable
final class CachedPoster extends ImageProvider<CachedPoster> {
  const CachedPoster(this.url, this.cache);

  final String url;
  final PosterCache cache;

  @override
  Future<CachedPoster> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    CachedPoster key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_load(decode));

  Future<ImageInfo> _load(ImageDecoderCallback decode) async {
    final bytes = await cache.fetch(url);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final codec = await decode(buffer);
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) => other is CachedPoster && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// Image réseau décodée à sa taille d'affichage.
///
/// `cacheWidth` est la mesure qui protège le plus la mémoire : une affiche de
/// 780 pixels occupe 1 Mo décodée à 342 pixels, contre 5 Mo à pleine taille.
class PosterImage extends ConsumerWidget {
  const PosterImage({
    required this.url,
    required this.decodeWidth,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    super.key,
  });

  final String? url;
  final int decodeWidth;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = placeholder ?? const ColoredBox(color: AeroColors.veil);
    final address = url;
    if (address == null) return fallback;
    return Image(
      image: ResizeImage(
        CachedPoster(address, ref.watch(posterCacheProvider)),
        width: decodeWidth,
        policy: ResizeImagePolicy.fit,
      ),
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded ? fallback : child,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
