import 'dart:async';

/// Met une synchronisation en attente, par exemple pendant une lecture.
///
/// Sur un Fire TV Stick, une synchronisation qui télécharge le catalogue et le
/// guide chez le même fournisseur que la vidéo, puis les analyse et les écrit,
/// prive le lecteur de débit et de processeur : l'image saccade et le son se
/// décale. En pause, elle s'arrête au prochain point sûr, ne télécharge plus
/// rien, et reprend une fois la lecture finie.
final class ImportPause {
  final StreamController<bool> _changes = StreamController<bool>.broadcast(
    sync: true,
  );
  Completer<void>? _resumed;

  /// Vrai tant que la synchronisation doit attendre.
  bool get isPaused => _resumed != null;

  /// Chaque changement : `true` à la mise en pause, `false` à la reprise.
  Stream<bool> get changes => _changes.stream;

  /// Se termine aussitôt hors pause, sinon à la reprise.
  Future<void> get resumed => _resumed?.future ?? Future<void>.value();

  void set({required bool paused}) {
    if (paused == isPaused) return;
    if (paused) {
      _resumed = Completer<void>();
    } else {
      _resumed!.complete();
      _resumed = null;
    }
    _changes.add(paused);
  }
}
