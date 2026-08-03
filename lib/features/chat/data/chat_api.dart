import 'package:dio/dio.dart';

import 'chat_dto.dart';

/// Solo HTTP. El backend resuelve el participante desde el token: ninguna
/// ruta recibe id de usuario (RF-09), y devuelve **403** si la conversacion
/// es de otros.
class ChatApi {
  const ChatApi(this._dio);

  final Dio _dio;

  /// `GET /chat/conversations` — RF-31. Sin paginar; incluye no leidos.
  Future<List<ConversacionDto>> conversaciones() async {
    final res = await _dio.get<List<dynamic>>('/chat/conversations');
    return (res.data ?? const [])
        .map((e) => ConversacionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /chat/conversations` — RF-31. **Idempotente**: con el mismo medico
  /// devuelve la conversacion existente, no una nueva.
  Future<ConversacionDto> abrir(int idMedico) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/chat/conversations',
      data: {'idMedico': idMedico},
    );
    return ConversacionDto.fromJson(res.data!);
  }

  /// `GET /chat/conversations/{id}/messages` — del mas nuevo al mas viejo.
  ///
  /// Pagina por **cursor** y no por numero de pagina: `antesDe` es el id del
  /// mensaje mas antiguo que ya se tiene. En un hilo que crece mientras se
  /// lee, la paginacion por offset repetiria o saltaria mensajes.
  Future<List<MensajeDto>> mensajes({
    required int idConversacion,
    int? antesDe,
    int limite = 30,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/chat/conversations/$idConversacion/messages',
      queryParameters: {'limit': limite, 'antesDe': ?antesDe},
    );
    return (res.data ?? const [])
        .map((e) => MensajeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /chat/conversations/{id}/messages` — RF-31, RF-34.
  ///
  /// El envio va por REST y el socket solo **avisa**: si fuera al reves, un
  /// mensaje enviado con el socket caido se perderia sin que nadie lo supiera.
  Future<MensajeDto> enviar({
    required int idConversacion,
    required String contenido,
    String? urlAdjunto,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/chat/conversations/$idConversacion/messages',
      data: {'contenido': contenido, 'urlAdjunto': ?urlAdjunto},
    );
    return MensajeDto.fromJson(res.data!);
  }

  /// `PATCH /chat/conversations/{id}/leidos` — RF-33.
  Future<void> marcarLeidos(int idConversacion) =>
      _dio.patch<dynamic>('/chat/conversations/$idConversacion/leidos');
}
