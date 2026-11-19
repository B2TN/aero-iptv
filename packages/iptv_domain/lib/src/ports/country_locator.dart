/// Pays où se trouve l'appareil, d'après son adresse IP.
abstract interface class CountryLocator {
  /// Code ISO 3166-1 du pays, en majuscules. Lève une `Failure` si le service
  /// ne répond pas.
  Future<String> country();
}
