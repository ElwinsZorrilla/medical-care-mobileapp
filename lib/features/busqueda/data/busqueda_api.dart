import 'package:dio/dio.dart';

import '../../../core/domain/pagina.dart';
import 'busqueda_dto.dart';

/// Solo HTTP. Las tres rutas son **públicas**: no exigen token.
class BusquedaApi {
  const BusquedaApi(this._dio);

  final Dio _dio;

  /// `GET /specialties` — RF-12. Sin paginar.
  Future<List<CatalogoEspecialidadDto>> especialidades() async {
    final res = await _dio.get<List<dynamic>>('/specialties');
    return (res.data ?? const [])
        .map((e) => CatalogoEspecialidadDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /doctors` — RF-14, RF-15.
  ///
  /// El único filtro es `especialidadId`: **no hay búsqueda por texto** en el
  /// backend (verificado en F00). Ver docs/BACKEND_ISSUES.md #8.
  Future<PaginaMedicosDto> medicos({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
    int? especialidadId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/doctors',
      queryParameters: {
        'page': pagina,
        'limit': limite,
        'especialidadId': ?especialidadId,
      },
    );
    return PaginaMedicosDto.fromJson(res.data!);
  }
}
