import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/cita_estado.dart';
import 'package:medicare/core/domain/modalidad.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/citas/data/citas_api.dart';
import 'package:medicare/features/citas/data/citas_dto.dart';
import 'package:medicare/features/citas/data/citas_repository.dart';
import 'package:medicare/features/citas/domain/cita.dart';

class _ApiFalsa extends CitasApi {
  _ApiFalsa({this.error, this.estado = 'PENDIENTE', this.total = 1})
    : super(Dio());

  final DioException? error;
  final String estado;
  final int total;

  CrearCitaDto? reservaEnviada;
  String? motivoCancelacion;

  /// Errores con la forma exacta que devolvió el backend en F00.
  static DioException http(int status, String mensaje) {
    final o = RequestOptions(path: '/appointments', method: 'POST');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: {'message': mensaje},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  CitaDto get _cita => CitaDto(
    idCita: 1,
    idPaciente: 1,
    idMedico: 2,
    fechaHoraInicio: '2026-08-17T12:00:00.000Z',
    fechaHoraFin: '2026-08-17T12:30:00.000Z',
    modalidad: 'PRESENCIAL',
    estado: estado,
    fechaCreacion: '2026-07-31T01:03:39.194Z',
    motivoConsulta: 'Dolor de cabeza',
  );

  @override
  Future<CitaDto> reservar(CrearCitaDto body) async {
    reservaEnviada = body;
    if (error != null) throw error!;
    return _cita;
  }

  @override
  Future<CitaDto> cancelar(int idCita, String motivo) async {
    motivoCancelacion = motivo;
    if (error != null) throw error!;
    return _cita;
  }

  @override
  Future<PaginaCitasDto> misCitas({int pagina = 1, int limite = 10}) async {
    if (error != null) throw error!;
    return PaginaCitasDto(
      data: [_cita],
      total: total,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<PaginaCitasDto> miAgenda({int pagina = 1, int limite = 10}) =>
      misCitas(pagina: pagina, limite: limite);
}

const _solicitud = SolicitudReserva(
  idMedico: 2,
  fecha: '2026-08-17',
  horaInicioApi: '2026-08-17T12:00:00.000Z',
  modalidad: ModalidadCita.presencial,
  motivoConsulta: 'Dolor de cabeza',
);

void main() {
  setUpAll(() async => AppTime.init());

  group('reservar — RF-19, RF-21', () {
    test('camino feliz', () async {
      final r = await CitasRepository(_ApiFalsa()).reservar(_solicitud);

      final c = r.valorONull!;
      expect(c.estado, CitaEstado.pendiente);
      expect(c.modalidad, ModalidadCita.presencial);
      expect(c.motivoConsulta, 'Dolor de cabeza');
      expect(c.duracion, const Duration(minutes: 30));
    });

    test('manda fecha y horaInicio, los dos, como exige el backend', () async {
      final api = _ApiFalsa();
      await CitasRepository(api).reservar(_solicitud);

      expect(api.reservaEnviada!.fecha, '2026-08-17');
      // El string ISO exacto que devolvió el endpoint de turnos, sin
      // reconstruir: reconstruirlo puede diferir en milisegundos.
      expect(api.reservaEnviada!.horaInicio, '2026-08-17T12:00:00.000Z');
    });
  });

  group('RF-20 / RNF-10 — el 409, el caso central', () {
    test('turno tomado: pide refrescar la grilla', () async {
      // Verificado con una carrera real en F00: el perdedor recibe esto.
      final r = await CitasRepository(
        _ApiFalsa(error: _ApiFalsa.http(409, 'Ese turno ya fue reservado')),
      ).reservar(_solicitud);

      final fallo = r.failureONull!;
      expect(
        ReaccionAConflicto.para(fallo),
        ReaccionAConflicto.refrescarTurnos,
      );
      // Mensaje llano, sin códigos ni jerga.
      expect(fallo.mensaje, 'Ese turno ya lo tomaron. Elige otra hora.');
      expect(fallo.mensaje, isNot(contains('409')));
    });

    test('perder la carrera contra otro paciente es el mismo caso', () async {
      final r = await CitasRepository(
        _ApiFalsa(
          error: _ApiFalsa.http(
            409,
            'Ese turno ya fue reservado por otro paciente',
          ),
        ),
      ).reservar(_solicitud);

      expect(
        ReaccionAConflicto.para(r.failureONull!),
        ReaccionAConflicto.refrescarTurnos,
      );
    });

    test('modalidad no admitida NO refresca la grilla', () async {
      // Mismo código HTTP, reacción opuesta. Refrescar acá le borraría al
      // usuario el turno que eligió sin arreglar nada: lo que falla es la
      // modalidad, no la disponibilidad.
      final r = await CitasRepository(
        _ApiFalsa(
          error: _ApiFalsa.http(
            409,
            'Ese turno solo admite modalidad PRESENCIAL',
          ),
        ),
      ).reservar(_solicitud);

      expect(
        ReaccionAConflicto.para(r.failureONull!),
        ReaccionAConflicto.corregirModalidad,
      );
      expect(r.failureONull!.mensaje, contains('PRESENCIAL'));
    });

    test('400 de turno fuera de franja también refresca, no es validación', () {
      // El 400 de esta ruta significa que la grilla quedó vieja. Mapearlo a
      // Validacion pintaría un campo en rojo cuando lo que hay que hacer es
      // actualizar los horarios.
      const fallo = TurnoInvalido();
      expect(
        ReaccionAConflicto.para(fallo),
        ReaccionAConflicto.refrescarTurnos,
      );
    });

    test('400 de turno fuera de franja llega como TurnoInvalido', () async {
      final r = await CitasRepository(
        _ApiFalsa(
          error: _ApiFalsa.http(
            400,
            'Ese turno no corresponde a ninguna franja de disponibilidad '
            'del médico',
          ),
        ),
      ).reservar(_solicitud);

      expect(r.failureONull, isA<TurnoInvalido>());
    });

    test('un conflicto desconocido solo muestra el mensaje', () async {
      final r = await CitasRepository(
        _ApiFalsa(error: _ApiFalsa.http(409, 'Algo raro pasó')),
      ).reservar(_solicitud);

      expect(
        ReaccionAConflicto.para(r.failureONull!),
        ReaccionAConflicto.mostrarMensaje,
      );
      expect(r.failureONull!.mensaje, 'Algo raro pasó');
    });

    test('sin conexión no es un conflicto', () async {
      final r = await CitasRepository(
        _ApiFalsa(
          error: DioException(
            requestOptions: RequestOptions(path: '/appointments'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).reservar(_solicitud);

      expect(r.failureONull, isA<SinConexion>());
    });
  });

  group('cancelar — RF-22', () {
    test('camino feliz: manda el motivo', () async {
      final api = _ApiFalsa(estado: 'CANCELADA');
      final r = await CitasRepository(
        api,
      ).cancelar(idCita: 1, motivo: 'Me surgió un imprevisto');

      expect(r.esOk, isTrue);
      expect(api.motivoCancelacion, 'Me surgió un imprevisto');
      expect(r.valorONull!.estado, CitaEstado.cancelada);
    });

    test('camino de error: 403 en cita ajena', () async {
      final r = await CitasRepository(
        _ApiFalsa(
          error: _ApiFalsa.http(403, 'No puedes cancelar una cita ajena'),
        ),
      ).cancelar(idCita: 1, motivo: 'x');

      expect(r.failureONull, isA<Prohibido>());
    });

    test('camino de error: 409 si ya estaba cancelada', () async {
      final r = await CitasRepository(
        _ApiFalsa(error: _ApiFalsa.http(409, 'La cita ya estaba cancelada')),
      ).cancelar(idCita: 1, motivo: 'x');

      expect(r.failureONull, isA<Conflicto>());
      expect(r.failureONull!.mensaje, contains('ya estaba cancelada'));
    });
  });

  group('listados — RF-24', () {
    test('mis citas: traduce y arma la página', () async {
      // total 30 con limite 10 => hay tres paginas. Con total 3 cabria todo
      // en una sola y `hayMas` seria correctamente false.
      final r = await CitasRepository(_ApiFalsa(total: 30)).misCitas();

      expect(r.valorONull!.items, hasLength(1));
      expect(r.valorONull!.total, 30);
      expect(r.valorONull!.hayMas, isTrue);
    });

    test('una sola pagina no pide mas', () async {
      final r = await CitasRepository(_ApiFalsa(total: 3)).misCitas();
      expect(r.valorONull!.hayMas, isFalse);
    });

    test('la agenda usa la otra ruta', () async {
      final r = await CitasRepository(_ApiFalsa()).miAgenda();
      expect(r.esOk, isTrue);
    });

    test('camino de error: estado desconocido falla ruidoso', () async {
      // Pintar una cita cancelada como pendiente haría que alguien se
      // presente a una consulta que no existe.
      final r = await CitasRepository(
        _ApiFalsa(estado: 'REPROGRAMADA'),
      ).misCitas();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorInesperado>());
    });

    test('camino de error: 500', () async {
      final r = await CitasRepository(
        _ApiFalsa(error: _ApiFalsa.http(500, 'boom')),
      ).misCitas();
      expect(r.failureONull, isA<ErrorServidor>());
    });
  });

  group('Cita', () {
    Cita cita({CitaEstado estado = CitaEstado.pendiente}) => Cita(
      id: 1,
      idPaciente: 1,
      idMedico: 2,
      inicioUtc: DateTime.utc(2026, 8, 17, 12),
      finUtc: DateTime.utc(2026, 8, 17, 12, 30),
      modalidad: ModalidadCita.presencial,
      estado: estado,
      creadaUtc: DateTime.utc(2026, 7, 31),
    );

    test('la hora se pinta en local, no en UTC', () {
      // 12:00Z es 08:00 en Santo Domingo.
      expect(AppTime.hora(cita().inicioUtc), '08:00');
    });

    test('una cita terminal no es cancelable', () {
      expect(cita().esCancelable, isTrue);
      expect(cita(estado: CitaEstado.cancelada).esCancelable, isFalse);
      expect(cita(estado: CitaEstado.completada).esCancelable, isFalse);
      expect(cita(estado: CitaEstado.noAsistio).esCancelable, isFalse);
    });

    test('yaPaso recibe el ahora en vez de leer el reloj', () {
      // Determinista en pruebas, y sin DateTime.now() suelto en la lógica.
      expect(cita().yaPaso(DateTime.utc(2026, 8, 17, 13)), isTrue);
      expect(cita().yaPaso(DateTime.utc(2026, 8, 17, 11)), isFalse);
    });
  });
}
