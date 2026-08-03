import 'package:dio/dio.dart';

import 'video_dto.dart';

/// Solo HTTP. El backend resuelve el participante desde el token: ninguna
/// ruta recibe id de usuario (RF-09), y devuelve 403 si la cita es de otros.
class VideoApi {
  const VideoApi(this._dio);

  final Dio _dio;

  /// `POST /appointments/{id}/videollamada` — RF-35.
  ///
  /// **Idempotente**: devuelve la sala existente si ya hay una. Si cada
  /// llamada creara una nueva, paciente y medico terminarian en salas
  /// distintas esperandose el uno al otro.
  ///
  /// 409 si la cita es presencial o esta cancelada.
  Future<VideollamadaDto> crearOObtener(int idCita) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/appointments/$idCita/videollamada',
    );
    return VideollamadaDto.fromJson(res.data!);
  }

  /// `GET /appointments/{id}/videollamada` — RF-36. 404 si no hay sala.
  Future<VideollamadaDto> porCita(int idCita) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/appointments/$idCita/videollamada',
    );
    return VideollamadaDto.fromJson(res.data!);
  }

  /// `PATCH /appointments/{id}/videollamada/estado` — RF-37.
  Future<VideollamadaDto> cambiarEstado(int idCita, String estado) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/appointments/$idCita/videollamada/estado',
      data: {'estado': estado},
    );
    return VideollamadaDto.fromJson(res.data!);
  }
}
