import 'package:dio/dio.dart';

import '../../../core/domain/cita_estado.dart';
import '../../../core/domain/modalidad.dart';
import '../../../core/domain/pagina.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../domain/cita.dart';
import 'citas_api.dart';
import 'citas_dto.dart';

/// Traduce DTO ↔ entidad y decide **una sola vez** cómo reaccionar a cada
/// forma de fallo de reserva.
class CitasRepository {
  const CitasRepository(this._api);

  final CitasApi _api;

  /// RF-19, RF-21 — reservar.
  ///
  /// ## El caso central del proyecto
  ///
  /// F00 verificó con una carrera real que dos pacientes contra el mismo
  /// turno producen `201` y `409`. El backend lo sostiene bien —transacción,
  /// bloqueo pesimista y restricción única en la tabla—, así que del lado del
  /// front la única pregunta es qué hacer con ese 409.
  ///
  /// **Nunca se reintenta en silencio.** El turno ya no existe: reintentar
  /// produciría el mismo 409 mientras el usuario mira la app pensar sin
  /// entender por qué. Se refresca la grilla y se le dice en lenguaje llano
  /// que elija otra hora.
  Future<Result<Cita>> reservar(SolicitudReserva solicitud) async {
    try {
      final dto = await _api.reservar(
        CrearCitaDto(
          idMedico: solicitud.idMedico,
          fecha: solicitud.fecha,
          horaInicio: solicitud.horaInicioApi,
          modalidad: solicitud.modalidad.apiValue,
          motivoConsulta: solicitud.motivoConsulta,
        ),
      );
      return Ok(_aEntidad(dto));
    } on DioException catch (e) {
      return Fallo(_falloDeReserva(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  /// Clasifica el fallo de reserva.
  ///
  /// El backend no expone código de error propio: el texto es lo único que
  /// distingue "alguien tomó el turno" de "esa modalidad no va acá". Se mira
  /// el mensaje **una vez, acá**, y hacia arriba viaja una decisión y no un
  /// string que cada pantalla tendría que volver a interpretar.
  Failure _falloDeReserva(DioException e) {
    final status = e.response?.statusCode;
    final mensaje = _mensajeServidor(e);
    final texto = mensaje.toLowerCase();

    // 400 en esta ruta NO es validación de formulario: significa que el turno
    // no corresponde a ninguna franja. La grilla del usuario quedó vieja.
    if (status == 400 && texto.contains('franja')) {
      return const TurnoInvalido(
        'Ese turno ya no está disponible. Actualizamos los horarios.',
      );
    }

    if (status == 409) {
      if (texto.contains('ya fue reservado')) {
        return const Conflicto(
          'Ese turno ya lo tomaron. Elige otra hora.',
          mensajeServidor: 'Ese turno ya fue reservado',
        );
      }
      // Modalidad y cualquier otro conflicto conservan el texto del
      // servidor: `reaccionA` lo usa para decidir qué hacer.
      return Conflicto(
        mensaje.isEmpty ? 'Esa reserva ya no es posible.' : mensaje,
        mensajeServidor: mensaje,
      );
    }

    return FailureMapper.desdeDio(e);
  }

  /// RF-22 — cancelar con motivo.
  Future<Result<Cita>> cancelar({
    required int idCita,
    required String motivo,
  }) async {
    try {
      return Ok(_aEntidad(await _api.cancelar(idCita, motivo)));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 403) {
        return const Fallo(Prohibido('Esa cita no es tuya.'));
      }
      if (status == 409) {
        return const Fallo(
          Conflicto(
            'Esa cita ya estaba cancelada.',
            mensajeServidor: 'ya estaba cancelada',
          ),
        );
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  /// RF-24 — mis citas (paciente).
  Future<Result<Pagina<Cita>>> misCitas({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar(
    () => _api.misCitas(pagina: pagina, limite: Pagina.limiteValido(limite)),
  );

  /// RF-24 — mi agenda (médico).
  Future<Result<Pagina<Cita>>> miAgenda({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) => _listar(
    () => _api.miAgenda(pagina: pagina, limite: Pagina.limiteValido(limite)),
  );

  Future<Result<Pagina<Cita>>> _listar(
    Future<PaginaCitasDto> Function() peticion,
  ) async {
    try {
      final dto = await peticion();
      return Ok(
        Pagina<Cita>(
          items: dto.data.map(_aEntidad).toList(),
          total: dto.total,
          pagina: dto.page,
          limite: dto.limit,
        ),
      );
    } on DioException catch (e) {
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Un estado o modalidad que la app no mapea. Falla ruidoso: pintar una
      // cita cancelada como pendiente haría que alguien se presente a una
      // consulta que no existe.
      return Fallo(ErrorInesperado(e.message.toString()));
    } on FormatException {
      return const Fallo(
        ErrorInesperado('El servidor devolvió una fecha inválida.'),
      );
    }
  }

  Cita _aEntidad(CitaDto dto) => Cita(
    id: dto.idCita,
    idPaciente: dto.idPaciente,
    idMedico: dto.idMedico,
    inicioUtc: DateTime.parse(dto.fechaHoraInicio).toUtc(),
    finUtc: DateTime.parse(dto.fechaHoraFin).toUtc(),
    modalidad: ModalidadCita.fromApi(dto.modalidad),
    estado: CitaEstado.fromApi(dto.estado),
    creadaUtc: DateTime.parse(dto.fechaCreacion).toUtc(),
    idCentro: dto.idCentro,
    idDisponibilidad: dto.idDisponibilidad,
    motivoConsulta: dto.motivoConsulta,
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
