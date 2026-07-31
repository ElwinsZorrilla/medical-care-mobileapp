import 'package:dio/dio.dart';

import 'agenda_dto.dart';

/// Solo HTTP.
class AgendaApi {
  const AgendaApi(this._dio);

  final Dio _dio;

  /// `GET /availability/me` — RF-16. Sin paginar, ordenado por día y hora.
  ///
  /// No recibe id: el backend resuelve el médico desde el token (RF-09).
  Future<List<DisponibilidadDto>> misFranjas() async {
    final res = await _dio.get<List<dynamic>>('/availability/me');
    return (res.data ?? const [])
        .map((e) => DisponibilidadDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /availability` — RF-16. **409** si solapa con otra franja activa.
  Future<DisponibilidadDto> crear(CrearDisponibilidadDto body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/availability',
      data: body.toJson(),
    );
    return DisponibilidadDto.fromJson(res.data!);
  }

  /// `PATCH /availability/{id}` — 409 si el cambio produce solape.
  Future<DisponibilidadDto> actualizar(
    int id,
    ActualizarDisponibilidadDto body,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/availability/$id',
      data: _sinNulos(body.toJson()),
    );
    return DisponibilidadDto.fromJson(res.data!);
  }

  /// `PATCH /availability/{id}/desactivar` — RF-17.
  ///
  /// El backend no ofrece "reactivar": desactivar es de una sola dirección.
  Future<DisponibilidadDto> desactivar(int id) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/availability/$id/desactivar',
    );
    return DisponibilidadDto.fromJson(res.data!);
  }

  /// Quita las claves nulas: en un PATCH, `null` significaría "borralo".
  static Map<String, dynamic> _sinNulos(Map<String, dynamic> json) => {
    for (final e in json.entries)
      if (e.value != null) e.key: e.value,
  };
}
