import 'package:dio/dio.dart';

import '../domain/pagina.dart';
import 'notificaciones_dto.dart';

/// Solo HTTP. Ninguna ruta recibe id de usuario: el backend resuelve el
/// destinatario desde el token (RF-09).
class NotificacionesApi {
  const NotificacionesApi(this._dio);

  final Dio _dio;

  /// `GET /notifications/me` — RF-28. Paginado, mas nuevas primero.
  Future<PaginaNotificacionesDto> bandeja({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications/me',
      queryParameters: {'page': pagina, 'limit': limite},
    );
    return PaginaNotificacionesDto.fromJson(res.data!);
  }

  /// `GET /notifications/me/no-leidas` — el contador del badge.
  Future<int> sinLeer() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notifications/me/no-leidas',
    );
    // El backend devuelve `{ "noLeidas": n }`.
    final data = res.data ?? const {};
    return (data['noLeidas'] ?? data['total'] ?? 0) as int;
  }

  /// `PATCH /notifications/{id}/leida` — RF-30. 404 si es de otro usuario.
  Future<NotificacionDto> marcarLeida(int id) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/notifications/$id/leida',
    );
    return NotificacionDto.fromJson(res.data!);
  }

  /// `PATCH /notifications/me/leidas` — RF-30, todas de una.
  Future<void> marcarTodasLeidas() =>
      _dio.patch<Map<String, dynamic>>('/notifications/me/leidas');
}
