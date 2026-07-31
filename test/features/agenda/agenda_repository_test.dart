import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/modalidad.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/agenda/data/agenda_api.dart';
import 'package:medicare/features/agenda/data/agenda_dto.dart';
import 'package:medicare/features/agenda/data/agenda_repository.dart';
import 'package:medicare/features/agenda/domain/disponibilidad.dart';

class _ApiFalsa extends AgendaApi {
  _ApiFalsa({this.error, this.diaSemana = 1, this.modalidad = 'PRESENCIAL'})
    : super(Dio());

  final DioException? error;
  final int diaSemana;
  final String modalidad;

  String? fechaPedida;
  int? medicoPedido;
  CrearDisponibilidadDto? creada;

  static DioException httpError(int status, [String? mensaje]) {
    final o = RequestOptions(path: '/availability');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: mensaje == null ? null : {'message': mensaje},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  DisponibilidadDto get _franja => DisponibilidadDto(
    idDisponibilidad: 1,
    idMedico: 5,
    diaSemana: diaSemana,
    horaInicio: '08:00',
    horaFin: '10:00',
    duracionSlotMin: 30,
    modalidad: modalidad,
    activo: true,
  );

  @override
  Future<List<DisponibilidadDto>> misFranjas() async {
    if (error != null) throw error!;
    return [_franja];
  }

  @override
  Future<DisponibilidadDto> crear(CrearDisponibilidadDto body) async {
    creada = body;
    if (error != null) throw error!;
    return _franja;
  }

  @override
  Future<DisponibilidadDto> desactivar(int id) async {
    if (error != null) throw error!;
    return _franja;
  }

  @override
  Future<List<TurnoDto>> turnos({
    required int idMedico,
    required String fecha,
  }) async {
    medicoPedido = idMedico;
    fechaPedida = fecha;
    if (error != null) throw error!;
    return const [
      TurnoDto(
        idDisponibilidad: 1,
        horaInicio: '2026-08-17T12:00:00.000Z',
        horaFin: '2026-08-17T12:30:00.000Z',
        modalidad: 'PRESENCIAL',
      ),
    ];
  }
}

void main() {
  setUpAll(() async => AppTime.init());

  group('franjas — RF-16', () {
    test('camino feliz: traduce hora local y día', () async {
      final r = await AgendaRepository(_ApiFalsa()).misFranjas();

      final f = r.valorONull!.single;
      expect(f.dia, DiaSemana.lunes);
      expect(f.horaInicio, const HoraDelDia(8, 0));
      expect(f.rango, '08:00 – 10:00');
      expect(f.turnosPorDia, 4);
    });

    test('manda el día con la numeración del backend', () async {
      final api = _ApiFalsa();
      await AgendaRepository(api).crear(
        dia: DiaSemana.lunes,
        horaInicio: const HoraDelDia(8, 0),
        horaFin: const HoraDelDia(10, 0),
        duracionSlotMin: 30,
        modalidad: ModalidadFranja.presencial,
      );
      // 1 = lunes, como getUTCDay(). Mandar el weekday de Dart (que también
      // es 1 para lunes, pero 7 para domingo) rompería el domingo.
      expect(api.creada!.diaSemana, 1);
      expect(api.creada!.horaInicio, '08:00');
    });

    test('camino de error: 409 conserva el mensaje del servidor', () async {
      // El backend usa 409 para el solape y para horaFin <= horaInicio. El
      // texto es lo único que los distingue.
      final r =
          await AgendaRepository(
            _ApiFalsa(
              error: _ApiFalsa.httpError(
                409,
                'La franja se solapa con otra disponibilidad activa',
              ),
            ),
          ).crear(
            dia: DiaSemana.lunes,
            horaInicio: const HoraDelDia(8, 0),
            horaFin: const HoraDelDia(10, 0),
            duracionSlotMin: 30,
            modalidad: ModalidadFranja.presencial,
          );

      expect(r.failureONull, isA<Conflicto>());
      expect(r.failureONull!.mensaje, contains('solapa'));
    });

    test('una franja AMBAS admite las dos modalidades de cita', () async {
      // Es el valor que solo existe en la franja: la cita concreta siempre
      // es PRESENCIAL o VIRTUAL.
      final r = await AgendaRepository(
        _ApiFalsa(modalidad: 'AMBAS'),
      ).misFranjas();

      final f = r.valorONull!.single;
      expect(f.modalidad, ModalidadFranja.ambas);
      expect(f.modalidad.admitidas, hasLength(2));
    });

    test('camino de error: modalidad desconocida falla ruidoso', () async {
      final r = await AgendaRepository(
        _ApiFalsa(modalidad: 'HIBRIDA'),
      ).misFranjas();
      expect(r.failureONull, isA<ErrorInesperado>());
    });

    test('camino de error: día fuera de rango falla ruidoso', () async {
      // Un día mal mapeado corre la agenda entera: el médico configura lunes
      // y sus pacientes ven turnos el domingo.
      final r = await AgendaRepository(_ApiFalsa(diaSemana: 9)).misFranjas();
      expect(r.failureONull, isA<ErrorInesperado>());
    });
  });

  group('desactivar — RF-17', () {
    test('camino feliz', () async {
      final r = await AgendaRepository(_ApiFalsa()).desactivar(1);
      expect(r.esOk, isTrue);
    });

    test('camino de error: 403 en franja ajena', () async {
      final r = await AgendaRepository(
        _ApiFalsa(error: _ApiFalsa.httpError(403)),
      ).desactivar(1);
      expect(r.failureONull, isA<Prohibido>());
      expect(r.failureONull!.mensaje, contains('tus propias'));
    });
  });

  group('turnos — RF-18, el punto crítico de RNF-18', () {
    test('manda la fecha en calendario dominicano, no UTC', () async {
      final api = _ApiFalsa();
      // 01:00Z del 18 es todavía lunes 17 a las 21:00 en Santo Domingo.
      await AgendaRepository(
        api,
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 18, 1));

      expect(
        api.fechaPedida,
        '2026-08-17',
        reason: 'mandar 2026-08-18 mostraría los turnos del día equivocado',
      );
    });

    test('dentro del día local coincide', () async {
      final api = _ApiFalsa();
      await AgendaRepository(
        api,
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 15));
      expect(api.fechaPedida, '2026-08-17');
    });

    test('el turno es un instante UTC y se pinta como hora local', () async {
      final r = await AgendaRepository(
        _ApiFalsa(),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 12));

      final t = r.valorONull!.single;
      expect(t.inicioUtc.isUtc, isTrue);
      // 12:00Z es 08:00 en Santo Domingo.
      expect(AppTime.hora(t.inicioUtc), '08:00');
      expect(t.duracion, const Duration(minutes: 30));
    });

    test('conserva el string crudo para reservar', () async {
      // Al reservar hay que mandar exactamente este valor. Reconstruirlo con
      // toIso8601String() puede diferir en milisegundos y el backend no
      // encontraría el turno.
      final r = await AgendaRepository(
        _ApiFalsa(),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17, 12));

      expect(r.valorONull!.single.inicioApi, '2026-08-17T12:00:00.000Z');
    });

    test('camino de error: sin conexión', () async {
      final r = await AgendaRepository(
        _ApiFalsa(
          error: DioException(
            requestOptions: RequestOptions(path: '/availability'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).turnos(idMedico: 5, diaUtc: DateTime.utc(2026, 8, 17));

      expect(r.failureONull, isA<SinConexion>());
    });
  });

  group('DiaSemana', () {
    test('0 es domingo, como getUTCDay()', () {
      expect(DiaSemana.fromApi(0), DiaSemana.domingo);
      expect(DiaSemana.fromApi(1), DiaSemana.lunes);
      expect(DiaSemana.fromApi(6), DiaSemana.sabado);
    });

    test('rechaza valores fuera de rango', () {
      expect(() => DiaSemana.fromApi(7), throwsA(isA<ArgumentError>()));
      expect(() => DiaSemana.fromApi(-1), throwsA(isA<ArgumentError>()));
    });

    test('convierte desde el weekday de Dart, que numera al revés', () {
      // Dart: 1 = lunes … 7 = domingo. El backend: 0 = domingo.
      expect(DiaSemana.desdeWeekdayDart(DateTime.monday), DiaSemana.lunes);
      expect(DiaSemana.desdeWeekdayDart(DateTime.sunday), DiaSemana.domingo);
      expect(DiaSemana.desdeWeekdayDart(DateTime.saturday), DiaSemana.sabado);
    });

    test('todo día tiene etiqueta y abreviatura', () {
      for (final d in DiaSemana.values) {
        expect(d.etiqueta, isNotEmpty);
        expect(d.abreviatura.length, 3);
      }
    });
  });

  group('HoraDelDia', () {
    test('parsea y serializa HH:mm', () {
      expect(HoraDelDia.parse('08:30')!.toApi(), '08:30');
      expect(HoraDelDia.parse('8:5'), isNull);
    });

    test('rechaza horas imposibles', () {
      expect(HoraDelDia.parse('25:00'), isNull);
      expect(HoraDelDia.parse('10:75'), isNull);
      expect(HoraDelDia.parse(null), isNull);
    });

    test('compara por minutos totales', () {
      expect(const HoraDelDia(8, 0) < const HoraDelDia(8, 30), isTrue);
      expect(const HoraDelDia(10, 0) > const HoraDelDia(9, 59), isTrue);
    });
  });

  group('solape — lo que el backend rechaza con 409', () {
    Disponibilidad franja(int hi, int hf, {DiaSemana dia = DiaSemana.lunes}) =>
        Disponibilidad(
          id: 1,
          idMedico: 5,
          dia: dia,
          horaInicio: HoraDelDia(hi, 0),
          horaFin: HoraDelDia(hf, 0),
          duracionSlotMin: 30,
          modalidad: ModalidadFranja.presencial,
          activo: true,
        );

    test('dos franjas que se pisan', () {
      expect(franja(8, 12).seSolapaCon(franja(10, 14)), isTrue);
    });

    test('pegadas no se solapan', () {
      // 08:00–10:00 y 10:00–12:00 son contiguas, no solapadas.
      expect(franja(8, 10).seSolapaCon(franja(10, 12)), isFalse);
    });

    test('distinto día nunca se solapa', () {
      expect(
        franja(8, 12).seSolapaCon(franja(8, 12, dia: DiaSemana.martes)),
        isFalse,
      );
    });
  });

  group('ModalidadFranja', () {
    test('AMBAS admite las dos de cita', () {
      expect(ModalidadFranja.ambas.admitidas, hasLength(2));
      expect(ModalidadFranja.ambas.admite(ModalidadCita.virtual), isTrue);
    });

    test('PRESENCIAL no admite virtual: eso es el otro 409', () {
      expect(ModalidadFranja.presencial.admite(ModalidadCita.virtual), isFalse);
    });

    test('la cita no tiene AMBAS', () {
      expect(ModalidadCita.values, hasLength(2));
      expect(
        () => ModalidadCita.fromApi('AMBAS'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
