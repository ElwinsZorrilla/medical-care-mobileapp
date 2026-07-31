import 'package:dio/dio.dart';

import '../../../core/domain/pagina.dart';
import 'citas_dto.dart';

/// Solo HTTP.
class CitasApi {
  const CitasApi(this._dio);

  final Dio _dio;

  /// `POST /appointments` — RF-19. Solo rol PACIENTE. **201**.
  ///
  /// Puede devolver 400 (turno fuera de franja) o 409 (turno tomado,
  /// modalidad no admitida). El repositorio los separa.
  Future<CitaDto> reservar(CrearCitaDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/appointments',
      data: body.toJson(),
    );
    return CitaDto.fromJson(res.data!);
  }

  /// `PATCH /appointments/{id}/cancelar` — RF-22.
  ///
  /// Lo puede hacer el paciente **o** el médico de la cita.
  Future<CitaDto> cancelar(int idCita, String motivo) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/appointments/$idCita/cancelar',
      data: CancelarCitaDto(motivo: motivo).toJson(),
    );
    return CitaDto.fromJson(res.data!);
  }

  /// `GET /appointments/me` — RF-24, rol PACIENTE.
  ///
  /// **Solo acepta paginación.** No hay `estado`, `desde` ni `hasta`: el
  /// filtrado por estado es del lado cliente (F00).
  Future<PaginaCitasDto> misCitas({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar('/appointments/me', pagina, limite);

  /// `GET /appointments/agenda` — RF-24, rol MEDICO.
  Future<PaginaCitasDto> miAgenda({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar('/appointments/agenda', pagina, limite);

  Future<PaginaCitasDto> _listar(String ruta, int pagina, int limite) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ruta,
      queryParameters: {'page': pagina, 'limit': limite},
    );
    return PaginaCitasDto.fromJson(res.data!);
  }
}
