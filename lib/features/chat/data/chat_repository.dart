import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../domain/chat.dart';
import 'chat_api.dart';
import 'chat_dto.dart';

/// Traduce DTO ↔ entidad y `DioException` → [Failure].
class ChatRepository {
  const ChatRepository(this._api);

  final ChatApi _api;

  /// RF-31 — hilos del usuario, con su contador de no leidos.
  Future<Result<List<Conversacion>>> conversaciones() =>
      _envolver(() async => (await _api.conversaciones()).map(_aConv).toList());

  /// RF-31 — abrir (o recuperar) la conversacion con un medico.
  Future<Result<Conversacion>> abrir(int idMedico) =>
      _envolver(() async => _aConv(await _api.abrir(idMedico)));

  /// Mensajes, del mas nuevo al mas viejo.
  Future<Result<List<Mensaje>>> mensajes({
    required int idConversacion,
    int? antesDe,
    int limite = 30,
  }) => _envolver(
    () async => (await _api.mensajes(
      idConversacion: idConversacion,
      antesDe: antesDe,
      // El backend rechaza `limit > 100` con 400.
      limite: limite > 100 ? 100 : limite,
    )).map(_aMensaje).toList(),
  );

  /// RF-31, RF-34 — enviar.
  Future<Result<Mensaje>> enviar({
    required int idConversacion,
    required String contenido,
    String? urlAdjunto,
  }) => _envolver(
    () async => _aMensaje(
      await _api.enviar(
        idConversacion: idConversacion,
        contenido: contenido,
        urlAdjunto: urlAdjunto,
      ),
    ),
  );

  /// RF-33 — marcar leidos los de la contraparte.
  Future<Result<void>> marcarLeidos(int idConversacion) =>
      _envolver(() => _api.marcarLeidos(idConversacion));

  Conversacion _aConv(ConversacionDto d) => Conversacion(
    id: d.idConversacion,
    idPaciente: d.idPaciente,
    idMedico: d.idMedico,
    noLeidos: d.noLeidos,
    ultimoMensajeUtc: d.fechaUltimoMensaje == null
        ? null
        : DateTime.parse(d.fechaUltimoMensaje!).toUtc(),
  );

  Mensaje _aMensaje(MensajeDto d) => Mensaje(
    id: d.idMensaje,
    idConversacion: d.idConversacion,
    idRemitente: d.idUsuarioRemitente,
    contenido: d.contenido,
    urlAdjunto: d.urlAdjunto,
    // `.toUtc()` explicito: un string sin `Z` daria hora del dispositivo y el
    // hilo saldria desordenado respecto a lo que ve la contraparte.
    enviadoUtc: DateTime.parse(d.fechaEnvio).toUtc(),
    leido: d.leido,
  );

  Future<Result<T>> _envolver<T>(Future<T> Function() peticion) async {
    try {
      return Ok(await peticion());
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      // 403 acá significa "esa conversacion no es tuya". El backend la filtra
      // por token, asi que el acceso cruzado ni siquiera se puede expresar.
      if (e.response?.statusCode == 403) {
        return const Fallo(Prohibido('Esa conversacion no es tuya.'));
      }
      return Fallo(FailureMapper.desdeDio(e));
    }
  }
}
