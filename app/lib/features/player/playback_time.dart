String _two(int number) => number.toString().padLeft(2, '0');

/// Temps de lecture : « 20:15 », ou « 1:05:12 » au-delà d'une heure.
String formatPlaybackTime(Duration value) {
  final hours = value.inHours;
  final minutes = _two(value.inMinutes.remainder(60));
  final seconds = _two(value.inSeconds.remainder(60));
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
