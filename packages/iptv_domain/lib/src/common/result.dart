import 'failure.dart';

/// Résultat explicite d'une opération pouvant échouer.
///
/// Le type scellé oblige l'appelant à traiter l'échec dans un `switch`.
sealed class Result<T> {
  const Result();
}

/// Opération réussie.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// Opération échouée.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
