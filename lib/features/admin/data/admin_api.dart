import 'package:dio/dio.dart';

import '../../../core/data/medico_dto.dart';
import '../../../core/domain/pagina.dart';
import 'admin_dto.dart';

/// Solo HTTP. Las tres rutas exigen sesión de ADMIN — el back devuelve 403
/// si no. El interceptor de `dioClienteProvider` ya adjunta el Bearer.
class AdminApi {
  const AdminApi(this._dio);

  final Dio _dio;

  /// `GET /doctors?estadoVerificacion=PENDIENTE` — cola de verificación.
  ///
  /// El filtro es del lado del servidor: sin él, la página siguiente podría
  /// tener pendientes que nunca se verían si se filtrara en el cliente.
  Future<PaginaMedicosAdminDto> pendientes({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/doctors',
      queryParameters: {
        'page': pagina,
        'limit': limite,
        'estadoVerificacion': 'PENDIENTE',
      },
    );
    return PaginaMedicosAdminDto.fromJson(res.data!);
  }

  /// `PATCH /doctors/:id/verificacion` — RF-11, lado admin.
  Future<MedicoDto> actualizarVerificacion({
    required int idMedico,
    required String estado,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/doctors/$idMedico/verificacion',
      data: {'estado': estado},
    );
    return MedicoDto.fromJson(res.data!);
  }
}
