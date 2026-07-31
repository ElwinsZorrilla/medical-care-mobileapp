import '../error/failure.dart';

/// Cuándo Riverpod puede reintentar solo un provider que falló.
///
/// **Hay que fijarla explícitamente.** El comportamiento por omisión de
/// Riverpod (`ProviderContainer.defaultRetry`) reintenta *cualquier* error que
/// no sea un `Error` de Dart —o sea, todos los [Failure]— hasta **10 veces**
/// con backoff de 200 ms a 6.4 s: unos **38 segundos** en total. Durante toda
/// esa espera el estado sigue siendo `AsyncLoading`, así que las pantallas
/// pintan el skeleton y el usuario ve una carga que no termina, sin mensaje y
/// sin nada que tocar. El `ErrorState` con su botón aparece más de medio
/// minuto después.
///
/// Reintentar tampoco es neutral: repetir un 409 de reserva vuelve a pedir un
/// turno que ya se sabe tomado (RF-20), y repetir un 403 insiste en un recurso
/// ajeno. Solo se reintenta lo que de verdad puede salir distinto sin que
/// cambie nada del lado del usuario.
///
/// Dos intentos, 300 ms y 900 ms: un bache de red se absorbe sin que se note,
/// y en el peor caso el error aparece a los ~1.2 s.
abstract final class PoliticaReintento {
  static const maxIntentos = 2;
  static const baseEspera = Duration(milliseconds: 300);

  /// Firma `Retry` de Riverpod: devolver `null` es "no reintentes".
  static Duration? decidir(int intentos, Object error) {
    if (intentos >= maxIntentos) return null;
    if (error is! Failure) return null;

    return switch (error) {
      // Transitorios: el mismo pedido, un momento después, puede salir bien.
      SinConexion() || ErrorServidor() => baseEspera * (intentos * 2 + 1),

      // Deterministas. Reintentar no cambia la respuesta y en algunos casos
      // es peor que no hacer nada.
      NoAutorizado() ||
      SesionExpirada() ||
      Prohibido() ||
      NoEncontrado() ||
      Validacion() ||
      TurnoInvalido() ||
      Conflicto() ||
      ErrorInesperado() => null,
    };
  }
}
