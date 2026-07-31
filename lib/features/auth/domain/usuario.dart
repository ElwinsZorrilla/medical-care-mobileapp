import '../../../core/domain/tipo_usuario.dart';

/// Usuario autenticado.
///
/// Entidad de dominio: sin `fromJson`, sin `dio`, sin Flutter. Si necesitara
/// serializarse, estaría en la capa equivocada — para eso está el DTO.
class Usuario {
  const Usuario({
    required this.id,
    required this.correo,
    required this.tipo,
    this.telefono,
    this.urlFoto,
  });

  final int id;
  final String correo;
  final TipoUsuario tipo;
  final String? telefono;
  final String? urlFoto;

  bool get esPaciente => tipo == TipoUsuario.paciente;
  bool get esMedico => tipo == TipoUsuario.medico;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Usuario &&
          other.id == id &&
          other.correo == correo &&
          other.tipo == tipo &&
          other.telefono == telefono &&
          other.urlFoto == urlFoto;

  @override
  int get hashCode => Object.hash(id, correo, tipo, telefono, urlFoto);
}

/// Estado de la sesión — **tres valores, no dos**.
///
/// Sin [SesionDesconocida] la app parpadea al arrancar: mientras se lee el
/// token de `SecureStore` —que es asíncrono— el estado sería "anónimo", el
/// guard mandaría a login, y un instante después el token aparecería y
/// redirigiría de nuevo. El usuario ve un flash de la pantalla de login cada
/// vez que abre la app.
///
/// Con el tercer estado, el guard sabe distinguir "todavía no sé" de "no hay
/// sesión" y se queda quieto hasta saberlo.
sealed class Sesion {
  const Sesion();

  /// Todavía no se leyó el almacenamiento. Estado inicial.
  const factory Sesion.desconocida() = SesionDesconocida;

  /// Hay sesión válida.
  const factory Sesion.autenticada(Usuario usuario) = SesionAutenticada;

  /// Se comprobó y no hay sesión.
  const factory Sesion.anonima() = SesionAnonima;

  /// El usuario, o `null` si no hay sesión resuelta.
  Usuario? get usuario;

  /// Si ya se sabe *algo*: o hay sesión o se comprobó que no la hay.
  ///
  /// El guard de rutas espera a que esto sea `true` antes de redirigir.
  bool get estaResuelta => this is! SesionDesconocida;

  bool get estaAutenticada => this is SesionAutenticada;
}

final class SesionDesconocida extends Sesion {
  const SesionDesconocida();

  @override
  Usuario? get usuario => null;
}

final class SesionAutenticada extends Sesion {
  const SesionAutenticada(this.usuario);

  @override
  final Usuario usuario;
}

final class SesionAnonima extends Sesion {
  const SesionAnonima();

  @override
  Usuario? get usuario => null;
}
