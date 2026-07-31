import '../error/failure.dart';

/// Éxito o [Failure], sin excepciones de por medio.
///
/// Se paga más ceremonia en cada llamada a cambio de que el compilador
/// recuerde que el error existe. Con `try/catch` es fácil escribir un camino
/// feliz que compila y falla en producción; acá no se puede leer el valor sin
/// decidir antes qué pasa si falló.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T valor) = Ok<T>;
  const factory Result.fallo(Failure failure) = Fallo<T>;

  bool get esOk => this is Ok<T>;
  bool get esFallo => this is Fallo<T>;

  /// El valor, o `null` si fue fallo.
  T? get valorONull => switch (this) {
    Ok<T>(:final valor) => valor,
    Fallo<T>() => null,
  };

  /// El fallo, o `null` si fue éxito.
  Failure? get failureONull => switch (this) {
    Ok<T>() => null,
    Fallo<T>(:final failure) => failure,
  };

  /// Obliga a resolver las dos ramas.
  R when<R>({
    required R Function(T valor) ok,
    required R Function(Failure failure) fallo,
  }) => switch (this) {
    Ok<T>(:final valor) => ok(valor),
    Fallo<T>(:final failure) => fallo(failure),
  };

  /// Transforma el valor y deja pasar el fallo intacto.
  Result<R> map<R>(R Function(T valor) transformar) => switch (this) {
    Ok<T>(:final valor) => Ok<R>(transformar(valor)),
    Fallo<T>(:final failure) => Fallo<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.valor);
  final T valor;

  @override
  String toString() => 'Ok($valor)';
}

final class Fallo<T> extends Result<T> {
  const Fallo(this.failure);
  final Failure failure;

  @override
  String toString() => 'Fallo($failure)';
}
