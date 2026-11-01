/// Erreur métier typée, transmise aux couches supérieures.
///
/// [message] ne doit jamais contenir d'URL ni d'identifiant : les URL Xtream
/// embarquent le mot de passe de l'abonné.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// Description technique, destinée aux journaux et non à l'affichage.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Le serveur n'a pas répondu : adresse erronée, réseau coupé ou délai dépassé.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Le serveur a répondu par une erreur qui ne met pas le compte en cause.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {required this.status});

  /// Statut HTTP. Il ne contient rien de sensible et peut être affiché.
  final int status;
}

/// Les identifiants de la source sont refusés ou absents.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {this.status});

  /// Statut HTTP du refus. `null` si le serveur a répondu normalement.
  final int? status;
}

/// Le quota d'un service externe est épuisé.
final class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message);
}

/// La réponse du fournisseur est illisible.
final class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

/// La base locale a refusé une opération.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// L'élément demandé n'existe plus, par exemple après une resynchronisation.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}
