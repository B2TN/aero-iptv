import 'memory_tier.dart';

/// Options mpv communes à toutes les lectures.
///
/// Deux choix corrigent le comportement par défaut de media_kit :
///
/// - **Pas de cache disque.** media_kit active `cache-on-disk`, dont le fichier
///   ne fait que grossir : une chaîne en direct finirait par saturer le
///   stockage d'un stick. Le cache reste donc en mémoire, borné par
///   `demuxer-max-bytes`.
/// - **Décodage audio logiciel.** `audio-spdif` vide interdit tout passthrough :
///   FFmpeg décode l'audio et le système reçoit du PCM, qu'il sait toujours
///   lire. C'est ce qui évite le silence des flux Dolby sur Fire TV. Sur
///   Android, la sortie OpenSL de media_kit n'accepte que deux canaux : mpv
///   réduit donc le son en stéréo.
abstract final class MpvProfile {
  static Map<String, String> base(MemoryTier tier) => {
    'cache': 'yes',
    'cache-on-disk': 'no',
    'demuxer-max-bytes': '${tier.forwardBytes}',
    // Interdit au tampon arrière d'emprunter la mémoire du tampon avant.
    'demuxer-donate-buffer': 'no',
    'audio-spdif': '',
  };
}
