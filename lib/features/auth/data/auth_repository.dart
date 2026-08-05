import 'package:dio/dio.dart';

import '../../../core/domain/tipo_usuario.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../../../core/storage/secure_store.dart';
import '../domain/usuario.dart';
import 'auth_api.dart';
import 'auth_dto.dart';

/// Traduce DTO → entidad y `DioException` → [Failure].
///
/// Es la única capa que sabe que existe HTTP. Hacia arriba solo salen
/// entidades y fallos de dominio.
class AuthRepository {
  /// Posicionales a propósito: Dart no admite parámetros con nombre
  /// privados, así que `{required this._api}` no compila. Con dos
  /// dependencias, posicional se lee bien y evita un `ignore` de lint.
  const AuthRepository(this._api, this._store);

  final AuthApi _api;
  final SecureStore _store;

  /// RF-03 — login.
  Future<Result<Usuario>> iniciarSesion({
    required String correo,
    required String contrasena,
  }) => _conSesion(
    () => _api.login(LoginRequestDto(correo: correo, contrasena: contrasena)),
    // El backend responde 401 tanto si el correo no existe como si la
    // contraseña está mal — a propósito, para no revelar qué correos están
    // registrados. El mensaje del front respeta esa ambigüedad.
    mensaje401: 'Correo o contraseña incorrectos.',
  );

  /// RF-01, RF-02 — registro.
  Future<Result<Usuario>> registrar({
    required String correo,
    required String contrasena,
    required TipoUsuario tipo,
    String? telefono,
  }) => _conSesion(
    () => _api.registrar(
      RegisterRequestDto(
        correo: correo,
        contrasena: contrasena,
        tipoUsuario: tipo.apiValue,
        telefono: telefono,
      ),
    ),
    mensaje409: 'Ese correo ya está registrado. Inicia sesión.',
  );

  /// Recupera la sesión guardada al arrancar.
  ///
  /// Devuelve `null` si no hay token: eso no es un error, es el caso normal
  /// de un usuario que nunca entró o que cerró sesión.
  Future<Result<Usuario?>> restaurarSesion() async {
    final token = await _store.leerAccessToken();
    if (token == null || token.isEmpty) return const Ok(null);

    try {
      final dto = await _api.yo();
      return Ok(_aEntidad(dto));
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      // 401 acá significa que ni el access ni el refresh sirven: el
      // interceptor ya lo intentó. Se limpia y se arranca como anónimo, sin
      // mostrar un error — el usuario no hizo nada mal.
      if (e.response?.statusCode == 401) {
        await _store.limpiar();
        return const Ok(null);
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  /// RF-05 — cerrar sesión.
  ///
  /// **Solo borra los tokens del dispositivo.** El backend no expone
  /// `/auth/logout` ni revoca refresh tokens (BACKEND_ISSUES.md #3), así que
  /// el token sigue siendo válido en el servidor hasta que expire, a los 7
  /// días. No hay nada que el front pueda hacer al respecto; queda declarado
  /// en la matriz de trazabilidad como cobertura parcial.
  Future<Result<void>> cerrarSesion() async {
    await _store.limpiar();
    return const Ok(null);
  }

  /// Ejecuta un flujo que devuelve tokens, los guarda y resuelve el usuario.
  Future<Result<Usuario>> _conSesion(
    Future<AuthTokensDto> Function() peticion, {
    String? mensaje401,
    String? mensaje409,
  }) async {
    try {
      final tokens = await peticion();
      await _store.guardarTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      // El backend no devuelve el usuario junto con los tokens, así que hace
      // falta una segunda llamada para conocer el rol. Sin el rol no se puede
      // decidir a qué pantalla entra.
      final dto = await _api.yo();
      return Ok(_aEntidad(dto));
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 && mensaje401 != null) {
        return Fallo(NoAutorizado(mensaje401));
      }
      if (status == 409 && mensaje409 != null) {
        return Fallo(Conflicto(mensaje409, mensajeServidor: mensaje409));
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Rol desconocido: el backend agregó un valor que la app no mapea.
      // Falla ruidoso en vez de dejar entrar a alguien con el rol equivocado.
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  Usuario _aEntidad(UsuarioDto dto) => Usuario(
    id: dto.idUsuario,
    correo: dto.correo,
    tipo: TipoUsuario.fromApi(dto.tipoUsuario),
    telefono: dto.telefono,
    urlFoto: dto.urlFoto,
  );
}
