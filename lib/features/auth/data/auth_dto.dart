import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_dto.freezed.dart';
part 'auth_dto.g.dart';

/// Respuesta de `/auth/register`, `/auth/login` y `/auth/refresh`.
///
/// **No trae el usuario.** El backend devuelve solo el par de tokens
/// (verificado en F00); para conocer el rol hay que llamar a `/auth/me`.
@freezed
abstract class AuthTokensDto with _$AuthTokensDto {
  const factory AuthTokensDto({
    required String accessToken,
    required String refreshToken,
  }) = _AuthTokensDto;

  factory AuthTokensDto.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensDtoFromJson(json);
}

/// Cuerpo de `POST /auth/login`.
///
/// Los nombres son los del backend: **`correo` y `contrasena`**, no
/// `email`/`password`. Y el `ValidationPipe` corre con
/// `forbidNonWhitelisted`, así que un campo de más devuelve 400: este DTO
/// serializa exactamente lo permitido, nada más.
@freezed
abstract class LoginRequestDto with _$LoginRequestDto {
  const factory LoginRequestDto({
    required String correo,
    required String contrasena,
  }) = _LoginRequestDto;

  factory LoginRequestDto.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestDtoFromJson(json);
}

/// Cuerpo de `POST /auth/register`.
@freezed
abstract class RegisterRequestDto with _$RegisterRequestDto {
  const factory RegisterRequestDto({
    required String correo,
    required String contrasena,
    required String tipoUsuario,
    String? telefono,
  }) = _RegisterRequestDto;

  factory RegisterRequestDto.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestDtoFromJson(json);
}

/// Respuesta de `GET /auth/me`.
///
/// Los campos anulables lo son en el backend: `telefono`, `urlFoto` y
/// `ultimoAcceso` pueden venir en `null`.
@freezed
abstract class UsuarioDto with _$UsuarioDto {
  const factory UsuarioDto({
    required int idUsuario,
    required String correo,
    required String tipoUsuario,
    required String estado,
    String? telefono,
    String? urlFoto,
    DateTime? fechaCreacion,
    DateTime? ultimoAcceso,
  }) = _UsuarioDto;

  factory UsuarioDto.fromJson(Map<String, dynamic> json) =>
      _$UsuarioDtoFromJson(json);
}
