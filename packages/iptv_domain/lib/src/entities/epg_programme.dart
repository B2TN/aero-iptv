/// Émission du guide des programmes. Les instants sont en UTC.
final class EpgProgramme {
  const EpgProgramme({
    required this.epgKey,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String epgKey;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime stop;
}
