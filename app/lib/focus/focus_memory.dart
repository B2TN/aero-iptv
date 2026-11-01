import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Se souvient de l'élément actif de chaque liste.
///
/// Un seul onglet reste monté pour économiser la mémoire : en y revenant,
/// l'utilisateur doit retrouver sa position.
final class FocusMemory {
  final Map<String, int> _indexes = {};

  int read(String key) => _indexes[key] ?? 0;

  void write(String key, int index) => _indexes[key] = index;

  /// Oublie les positions dont la clé commence par [prefix].
  void clear(String prefix) =>
      _indexes.removeWhere((key, _) => key.startsWith(prefix));
}

final focusMemoryProvider = Provider<FocusMemory>((ref) => FocusMemory());
