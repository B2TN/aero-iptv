import 'text_folding.dart';

final RegExp _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Calcule la clé qui identifie les doublons d'une même chaîne ou série.
abstract final class GroupingKey {
  /// Réduit un titre déjà nettoyé à ses lettres et ses chiffres.
  ///
  /// `+` et `&` sont conservés sous forme de mot, car « Canal+ » et « Canal »
  /// sont deux chaînes différentes, tout comme « E4 » et « E4 +1 ».
  static String of(String title) => lowerWithoutDiacritics(
    title,
  ).replaceAll('&', ' and ').replaceAll('+', ' plus ').replaceAll(_nonWord, '');
}
