import 'package:iptv_domain/iptv_domain.dart';

import 'memory_tier.dart';
import 'stream_relay.dart';

/// Marge ajoutée à la réserve : au-delà de `cache-secs`, mpv cesse de lire le
/// flux et ne pourrait pas compenser une irrégularité du réseau.
const int _readaheadMarginSeconds = 2;

/// Le relais peut attendre que le panneau libère une connexion, et un serveur met
/// parfois plusieurs secondes à réveiller une chaîne : mpv ne doit pas abandonner
/// avant eux.
const String _networkTimeout = '20';

/// Réserve à reconstituer après un manque. Une seconde ferait repartir la vidéo
/// aussitôt pour la bloquer plus loin, en saccades.
const String _vodResumeSeconds = '2';

/// Traduit le réglage de stabilité en options mpv.
abstract final class LiveBufferPolicy {
  /// Options de mise en mémoire tampon pour [request].
  ///
  /// Pour une chaîne en direct, `cache-pause-initial` retarde le démarrage
  /// jusqu'à ce que `cache-pause-wait` secondes soient en réserve : le lecteur
  /// reste ensuite ce même temps derrière le direct. Si le flux est trop lourd
  /// pour la mémoire allouée, mpv démarre plus tôt au lieu de bloquer.
  static Map<String, String> optionsFor(
    PlaybackRequest request,
    MemoryTier tier,
  ) {
    if (!request.isLive) {
      return {
        if (StreamRelay.canCarry(request.stream.url))
          'demuxer-max-bytes': '${tier.relayedForwardBytes}',
        'demuxer-max-back-bytes': '${tier.backBytes}',
        'cache-secs': '120',
        'cache-pause-initial': 'yes',
        'cache-pause-wait': _vodResumeSeconds,
        'network-timeout': _networkTimeout,
      };
    }
    final delay = request.liveDelaySeconds.clamp(0, maxLiveDelaySeconds);
    return {
      // Aucun retour en arrière en direct : le tampon arrière serait perdu.
      'demuxer-max-back-bytes': '0',
      'cache-secs': '${delay + _readaheadMarginSeconds}',
      'cache-pause-initial': delay > 0 ? 'yes' : 'no',
      'cache-pause-wait': '${delay > 0 ? delay : 1}',
      'network-timeout': _networkTimeout,
    };
  }
}
