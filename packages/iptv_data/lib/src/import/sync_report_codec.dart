import 'dart:convert';

import 'package:iptv_domain/iptv_domain.dart';

/// Relevé de synchronisation gardé en JSON avec sa playlist.
abstract final class SyncReportCodec {
  static String encode(SyncReport report) => jsonEncode({
    'at': report.finishedAt.millisecondsSinceEpoch,
    'full': report.full,
    'steps': [
      for (final step in report.steps)
        {
          'phase': step.phase.name,
          'ms': step.duration.inMilliseconds,
          'received': step.received,
          'changed': step.changed,
        },
    ],
  });

  /// `null` pour un texte illisible, par exemple d'une version future.
  static SyncReport? decode(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      final at = json['at'];
      final steps = json['steps'];
      if (at is! int || steps is! List) return null;
      return SyncReport(
        finishedAt: DateTime.fromMillisecondsSinceEpoch(at),
        full: json['full'] == true,
        steps: [
          for (final step in steps)
            if (step is Map<String, dynamic>) ?_step(step),
        ],
      );
    } on FormatException {
      return null;
    }
  }

  static SyncStep? _step(Map<String, dynamic> json) {
    final phase = SyncPhase.values
        .where((phase) => phase.name == json['phase'])
        .firstOrNull;
    final ms = json['ms'];
    if (phase == null || ms is! int) return null;
    final received = json['received'];
    final changed = json['changed'];
    return SyncStep(
      phase,
      Duration(milliseconds: ms),
      received: received is int ? received : 0,
      changed: changed is int ? changed : 0,
    );
  }
}
