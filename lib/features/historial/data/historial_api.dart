import 'package:dio/dio.dart';

import '../../../core/domain/pagina.dart';
import 'historial_dto.dart';

/// Solo HTTP.
class HistorialApi {
  const HistorialApi(this._dio);

  final Dio _dio;

  /// `POST /consultations` — RF-25, RF-26. Solo el médico tratante.
  ///
  /// **Efecto secundario importante:** registrar la consulta mueve la cita a
  /// `COMPLETADA`. Es la única forma de alcanzar ese estado — no existe
  /// endpoint de transición (BACKEND_ISSUES.md #4).
  Future<ConsultaDto> registrar(CrearConsultaDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/consultations',
      data: body.toJson()..removeWhere((_, v) => v == null),
    );
    return ConsultaDto.fromJson(res.data!);
  }

  /// `POST /consultations/{id}/recetas` — RF-26, para agregar después.
  Future<ConsultaDto> agregarRecetas(
    int idConsulta,
    List<CrearRecetaDto> recetas,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/consultations/$idConsulta/recetas',
      data: {'recetas': recetas.map((r) => r.toJson()).toList()},
    );
    return ConsultaDto.fromJson(res.data!);
  }

  /// `GET /consultations/me` — RF-27, rol PACIENTE.
  ///
  /// El backend resuelve el paciente desde el token: **no hay forma de pedir
  /// el historial de otro** (RNF-06). El filtrado no es opcional del lado
  /// servidor, así que el acceso cruzado ni siquiera se puede expresar.
  Future<PaginaConsultasDto> miHistorial({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar('/consultations/me', pagina, limite);

  /// `GET /consultations/atendidas` — RF-27, rol MEDICO.
  Future<PaginaConsultasDto> atendidas({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar('/consultations/atendidas', pagina, limite);

  Future<PaginaConsultasDto> _listar(
    String ruta,
    int pagina,
    int limite,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ruta,
      queryParameters: {'page': pagina, 'limit': limite},
    );
    return PaginaConsultasDto.fromJson(res.data!);
  }
}
