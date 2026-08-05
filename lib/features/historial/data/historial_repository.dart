import 'package:dio/dio.dart';

import '../../../core/domain/pagina.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../domain/consulta.dart';
import 'historial_api.dart';
import 'historial_dto.dart';

/// Traduce DTO ↔ entidad y `DioException` → [Failure].
class HistorialRepository {
  const HistorialRepository(this._api);

  final HistorialApi _api;

  /// RF-25, RF-26 — registrar consulta (y sus recetas, en una sola llamada).
  ///
  /// El 409 tiene tres causas y las tres significan que **esa cita ya no
  /// admite consulta**: cancelada, ya completada, o no asistió. El mensaje
  /// del servidor lo dice, así que se conserva en vez de inventar uno.
  Future<Result<Consulta>> registrar(SolicitudConsulta solicitud) async {
    try {
      final dto = await _api.registrar(
        CrearConsultaDto(
          idCita: solicitud.idCita,
          diagnostico: solicitud.diagnostico,
          tratamiento: solicitud.tratamiento,
          observaciones: solicitud.observaciones,
          // `toJson` deja fuera las claves sin valor: el backend no valida
          // y mandar nulos ensuciaría el jsonb del historial.
          signosVitales: solicitud.signosVitales?.toJson(),
          recetas: solicitud.recetas.isEmpty
              ? null
              : solicitud.recetas
                    .map(
                      (r) => CrearRecetaDto(
                        medicamento: r.medicamento,
                        dosis: r.dosis,
                        frecuencia: r.frecuencia,
                        duracionDias: r.duracionDias,
                        indicaciones: r.indicaciones,
                      ),
                    )
                    .toList(),
        ),
      );
      return Ok(_aEntidad(dto));
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(_falloAlRegistrar(e));
    }
  }

  Failure _falloAlRegistrar(DioException e) {
    final status = e.response?.statusCode;
    final mensaje = _mensajeServidor(e);

    if (status == 403) {
      return const Prohibido(
        'Solo el médico de esa cita puede registrar la consulta.',
      );
    }
    if (status == 409) {
      return Conflicto(
        mensaje.isEmpty ? 'Esa cita ya no admite consulta.' : mensaje,
        mensajeServidor: mensaje,
      );
    }
    return FailureMapper.desdeDio(e);
  }

  /// RF-27 — historial del paciente autenticado.
  Future<Result<Pagina<Consulta>>> miHistorial({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar(
    () => _api.miHistorial(pagina: pagina, limite: Pagina.limiteValido(limite)),
  );

  /// RF-27 — consultas que atendió el médico autenticado.
  Future<Result<Pagina<Consulta>>> atendidas({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar(
    () => _api.atendidas(pagina: pagina, limite: Pagina.limiteValido(limite)),
  );

  Future<Result<Pagina<Consulta>>> _listar(
    Future<PaginaConsultasDto> Function() peticion,
  ) async {
    try {
      final dto = await peticion();
      return Ok(
        Pagina<Consulta>(
          items: dto.data.map(_aEntidad).toList(),
          total: dto.total,
          pagina: dto.page,
          limite: dto.limit,
        ),
      );
    } on TypeError catch (e) {
      // Un campo con otro tipo del declarado. `Result<T>` promete que ningun
      // camino lanza; sin esto la promesa era falsa y la app se cerraba.
      return Fallo(ContratoRoto('$e'));
    } on FormatException catch (e) {
      // Fecha, numero o `Decimal` ilegible.
      return Fallo(ContratoRoto('$e'));
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    }
  }

  Consulta _aEntidad(ConsultaDto dto) => Consulta(
    id: dto.idConsulta,
    idCita: dto.idCita,
    idPaciente: dto.idPaciente,
    idMedico: dto.idMedico,
    diagnostico: dto.diagnostico,
    registradaUtc: DateTime.parse(dto.fechaRegistro).toUtc(),
    tratamiento: dto.tratamiento,
    observaciones: dto.observaciones,
    signosVitales: SignosVitales.fromJson(dto.signosVitales),
    recetas: dto.recetas
        .map(
          (r) => Receta(
            id: r.idReceta,
            medicamento: r.medicamento,
            dosis: r.dosis,
            frecuencia: r.frecuencia,
            duracionDias: r.duracionDias,
            indicaciones: r.indicaciones,
          ),
        )
        .toList(),
  );

  String _mensajeServidor(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return '';
    final mensaje = data['message'];
    return switch (mensaje) {
      final String s => s,
      final List<dynamic> l => l.join(' '),
      _ => '',
    };
  }
}
