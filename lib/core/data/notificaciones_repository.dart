import 'package:dio/dio.dart';

import '../domain/notificacion.dart';
import '../domain/pagina.dart';
import '../error/failure.dart';
import '../error/failure_mapper.dart';
import '../network/result.dart';
import 'notificaciones_api.dart';
import 'notificaciones_dto.dart';

/// Traduce DTO → entidad y `DioException` → [Failure].
class NotificacionesRepository {
  const NotificacionesRepository(this._api);

  final NotificacionesApi _api;

  /// RF-28 — la bandeja.
  Future<Result<Pagina<Notificacion>>> bandeja({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _envolver(() async {
    final dto = await _api.bandeja(
      pagina: pagina,
      // El backend rechaza `limit > 50` con 400.
      limite: Pagina.limiteValido(limite),
    );
    return Pagina<Notificacion>(
      items: dto.data.map(_aNotificacion).toList(),
      total: dto.total,
      pagina: dto.page,
      limite: dto.limit,
    );
  });

  /// Cuantas sin leer — el numero del badge.
  Future<Result<int>> sinLeer() => _envolver(_api.sinLeer);

  /// RF-30 — marcar una.
  Future<Result<Notificacion>> marcarLeida(int id) =>
      _envolver(() async => _aNotificacion(await _api.marcarLeida(id)));

  /// RF-30 — marcar todas.
  Future<Result<void>> marcarTodasLeidas() => _envolver(_api.marcarTodasLeidas);

  Notificacion _aNotificacion(NotificacionDto dto) => Notificacion(
    id: dto.idNotificacion,
    tipo: TipoNotificacion.fromApi(dto.tipo),
    titulo: dto.titulo,
    cuerpo: dto.cuerpo,
    leida: dto.leida,
    // El backend manda ISO-8601 UTC. `.toUtc()` explicito: un string sin `Z`
    // daria un DateTime local y la antiguedad saldria corrida cuatro horas.
    enviadaUtc: DateTime.parse(dto.fechaEnvio).toUtc(),
    idCita: dto.idCita,
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
      // 404 al marcar leida significa "esa notificacion no es tuya": el
      // backend filtra por token y no distingue inexistente de ajena.
      if (e.response?.statusCode == 404) {
        return const Fallo(NoEncontrado('Esa notificacion ya no esta.'));
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Tipo desconocido: falla ruidoso en vez de pintar un icono generico
      // donde deberia decir que se cancelo una cita.
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }
}
