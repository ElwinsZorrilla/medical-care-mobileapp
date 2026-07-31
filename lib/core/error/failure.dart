/// Errores de dominio.
///
/// El error de red es un **valor esperado**, no algo excepcional: se devuelve,
/// no se lanza. Eso obliga a manejarlo en cada llamada en vez de dejarlo
/// burbujear hasta un `catch` genérico tres capas más arriba.
///
/// El `mensaje` viene **ya redactado en español, desde el lado del usuario**.
/// La UI lo pinta tal cual: si un widget tiene un `switch` sobre `statusCode`,
/// la abstracción se rompió.
sealed class Failure {
  const Failure(this.mensaje);

  /// Listo para pintar. Dice qué pasó y qué hacer, sin pedir disculpas.
  final String mensaje;

  @override
  String toString() => '$runtimeType: $mensaje';
}

/// Sin red, DNS caído o timeout.
final class SinConexion extends Failure {
  const SinConexion([
    super.mensaje =
        'Sin conexión. Revisa tus datos o el wifi e intenta de nuevo.',
  ]);
}

/// 401 con sesión recuperable: el interceptor va a intentar refrescar.
final class NoAutorizado extends Failure {
  const NoAutorizado([super.mensaje = 'Tu sesión no es válida.']);
}

/// El refresh falló o no hay sesión. Hay que volver a entrar.
final class SesionExpirada extends Failure {
  const SesionExpirada([
    super.mensaje = 'Tu sesión expiró. Inicia sesión de nuevo.',
  ]);
}

/// 403 — rol incorrecto, recurso ajeno o usuario bloqueado.
final class Prohibido extends Failure {
  const Prohibido([super.mensaje = 'No tienes permiso para hacer esto.']);
}

/// 404.
final class NoEncontrado extends Failure {
  const NoEncontrado([super.mensaje = 'No encontramos lo que buscabas.']);
}

/// 400 con errores de validación por campo.
///
/// El backend manda `message` como **arreglo** de strings cuando falla la
/// validación (`ValidationPipe` de NestJS). Ver docs/API_CONTRACT.md §1.
final class Validacion extends Failure {
  const Validacion(super.mensaje, {this.errores = const []});

  /// Mensajes crudos, uno por regla incumplida. Sirven para marcar campos.
  final List<String> errores;
}

/// 400 de reserva: el turno no corresponde a ninguna franja del médico.
///
/// **No es un error de formulario.** Comparte código HTTP con la validación
/// pero significa otra cosa: la grilla que ve el usuario quedó vieja. Si se
/// mapeara a [Validacion] se pintaría como campo inválido en vez de refrescar
/// los turnos. Ver docs/API_CONTRACT.md §7.
final class TurnoInvalido extends Failure {
  const TurnoInvalido([
    super.mensaje = 'Ese turno ya no está disponible. Actualiza los horarios.',
  ]);
}

/// 409 — el conflicto.
///
/// En este backend el 409 está **sobrecargado**: turno tomado, cita ya
/// cancelada, correo repetido, franja solapada y modalidad no admitida
/// comparten código. No hay campo de error propio, así que la única forma de
/// distinguirlos es el texto. Por eso se conserva [mensajeServidor].
///
/// El caso central es RF-20: dos pacientes pidiendo el mismo turno. La
/// respuesta correcta nunca es reintentar en silencio.
final class Conflicto extends Failure {
  const Conflicto(super.mensaje, {this.mensajeServidor = ''});

  /// Texto crudo del backend, para que el repositorio decida el subtipo.
  final String mensajeServidor;

  /// Si el conflicto es "alguien tomó ese turno antes".
  ///
  /// Cuando es cierto, la UI **refresca la grilla** y avisa. Cuando no
  /// —por ejemplo, modalidad equivocada— refrescar no arregla nada y solo
  /// haría perder al usuario lo que ya eligió.
  bool get esTurnoTomado =>
      mensajeServidor.toLowerCase().contains('ya fue reservado');
}

/// 5xx.
final class ErrorServidor extends Failure {
  const ErrorServidor([
    super.mensaje = 'El servidor tuvo un problema. Intenta en un momento.',
  ]);
}

/// Cualquier otra cosa: respuesta con forma inesperada, parseo roto.
final class ErrorInesperado extends Failure {
  const ErrorInesperado([super.mensaje = 'Algo salió mal. Intenta de nuevo.']);
}
