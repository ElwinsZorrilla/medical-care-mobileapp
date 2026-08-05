import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../domain/videollamada.dart';
import 'video_api.dart';
import 'video_dto.dart';

/// Traduce DTO ↔ entidad y `DioException` → [Failure].
class VideoRepository {
  const VideoRepository(this._api);

  final VideoApi _api;

  /// RF-35 — crear o recuperar la sala.
  Future<Result<Videollamada>> abrirSala(int idCita) =>
      _envolver(() async => _aDominio(await _api.crearOObtener(idCita)));

  /// RF-36 — consultar la sala. `NoEncontrado` si la cita aun no tiene.
  Future<Result<Videollamada>> porCita(int idCita) =>
      _envolver(() async => _aDominio(await _api.porCita(idCita)));

  /// RF-37 — mover el estado.
  Future<Result<Videollamada>> cambiarEstado(
    int idCita,
    EstadoVideollamada estado,
  ) => _envolver(
    () async => _aDominio(await _api.cambiarEstado(idCita, estado.api)),
  );

  Videollamada _aDominio(VideollamadaDto d) {
    final estado = EstadoVideollamada.desdeApi(d.estado);
    if (estado == null) {
      // Pintar "Programada" donde el servidor dijo algo que no se entiende
      // llevaria a tocar "Entrar" en una consulta que ya termino.
      throw _EstadoDesconocido(d.estado);
    }
    return Videollamada(
      id: d.idVideollamada,
      idCita: d.idCita,
      proveedor: d.proveedor,
      urlSala: d.urlSala,
      estado: estado,
      // `.toUtc()` explicito: un string sin `Z` daria hora del dispositivo.
      inicioRealUtc: d.horaInicioReal == null
          ? null
          : DateTime.parse(d.horaInicioReal!).toUtc(),
      finRealUtc: d.horaFinReal == null
          ? null
          : DateTime.parse(d.horaFinReal!).toUtc(),
    );
  }

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
      // 409 aca es "esa cita es presencial", "esta cancelada" o "ese salto de
      // estado no existe". `FailureMapper` ya conserva el mensaje del
      // servidor, que es lo unico que distingue los tres casos.
      return Fallo(FailureMapper.desdeDio(e));
    } on _EstadoDesconocido catch (e) {
      return Fallo(
        ErrorInesperado(
          'El servidor devolvio un estado de videollamada desconocido: '
          '${e.valor}.',
        ),
      );
    }
  }
}

class _EstadoDesconocido implements Exception {
  const _EstadoDesconocido(this.valor);
  final String valor;
}
