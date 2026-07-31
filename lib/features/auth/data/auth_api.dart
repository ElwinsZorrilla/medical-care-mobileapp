import 'package:dio/dio.dart';

import 'auth_dto.dart';

/// Solo HTTP. No traduce errores ni decide nada: eso es del repositorio.
class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// `POST /auth/register` → **201**.
  Future<AuthTokensDto> registrar(RegisterRequestDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: body.toJson(),
    );
    return AuthTokensDto.fromJson(res.data!);
  }

  /// `POST /auth/login` → **201**, no 200.
  ///
  /// Nest usa 201 por defecto en `POST` y el controlador no declara
  /// `@HttpCode(200)`. El Swagger dice 200 y la respuesta real dice 201; el
  /// cliente acepta cualquier 2xx (ver `DioClient.validateStatus`).
  Future<AuthTokensDto> login(LoginRequestDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: body.toJson(),
    );
    return AuthTokensDto.fromJson(res.data!);
  }

  /// `GET /auth/me` → 200.
  Future<UsuarioDto> yo() async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/me');
    return UsuarioDto.fromJson(res.data!);
  }
}
