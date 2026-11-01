/// Catégorie de mémoire de l'appareil, qui fixe la taille des tampons vidéo.
enum MemoryTier {
  /// Stick de 1 à 1,5 Go. 32 Mio contiennent environ 25 s de flux à 10 Mbit/s.
  low(
    forwardBytes: 32 * _mebibyte,
    backBytes: 4 * _mebibyte,
    relayWindowBytes: 36 * _mebibyte,
  ),

  /// Appareil TV de 2 Go et plus.
  standard(
    forwardBytes: 64 * _mebibyte,
    backBytes: 16 * _mebibyte,
    relayWindowBytes: 96 * _mebibyte,
  ),

  /// PC. Ces valeurs sont les réglages par défaut de mpv.
  desktop(
    forwardBytes: 150 * _mebibyte,
    backBytes: 50 * _mebibyte,
    relayWindowBytes: 210 * _mebibyte,
  );

  const MemoryTier({
    required this.forwardBytes,
    required this.backBytes,
    required this.relayWindowBytes,
  });

  /// Données mises en réserve à l'avance.
  final int forwardBytes;

  /// Données conservées derrière la position, pour les retours en arrière.
  final int backBytes;

  /// Fenêtre du relais. Elle doit contenir ce que mpv relit après un changement
  /// de piste : tout son tampon, plus les onze secondes qui le précèdent.
  final int relayWindowBytes;

  /// Tampon de mpv quand le relais assure l'essentiel de la mise en réserve.
  int get relayedForwardBytes => forwardBytes ~/ 4;
}

const int _mebibyte = 1024 * 1024;
