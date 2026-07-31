import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/historial/data/historial_api.dart';
import 'package:medicare/features/historial/data/historial_dto.dart';
import 'package:medicare/features/historial/data/historial_repository.dart';
import 'package:medicare/features/historial/domain/consulta.dart';

class _ApiFalsa extends HistorialApi {
  _ApiFalsa({this.error, this.vitales, this.recetas = const []}) : super(Dio());

  final DioException? error;
  final Map<String, dynamic>? vitales;
  final List<RecetaDto> recetas;

  CrearConsultaDto? registrada;

  static DioException http(int status, String mensaje) {
    final o = RequestOptions(path: '/consultations', method: 'POST');
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

  ConsultaDto get _consulta => ConsultaDto(
    idConsulta: 1,
    idCita: 7,
    idPaciente: 3,
    idMedico: 5,
    diagnostico: 'Faringitis viral',
    fechaRegistro: '2026-08-17T14:30:00.000Z',
    tratamiento: 'Reposo e hidratación',
    signosVitales: vitales,
    recetas: recetas,
  );

  @override
  Future<ConsultaDto> registrar(CrearConsultaDto body) async {
    registrada = body;
    if (error != null) throw error!;
    return _consulta;
  }

  @override
  Future<PaginaConsultasDto> miHistorial({
    int pagina = 1,
    int limite = 10,
  }) async {
    if (error != null) throw error!;
    return PaginaConsultasDto(
      data: [_consulta],
      total: 1,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<PaginaConsultasDto> atendidas({int pagina = 1, int limite = 10}) =>
      miHistorial(pagina: pagina, limite: limite);
}

void main() {
  setUpAll(() async => AppTime.init());

  group('SignosVitales — el jsonb sin esquema', () {
    test('lee las claves canónicas del spec', () {
      final v = SignosVitales.fromJson({
        'presionArterial': '120/80',
        'temperatura': 37.2,
        'pulso': 78,
      })!;

      expect(v.presionArterial, '120/80');
      expect(v.temperatura, 37.2);
      // El backend usa `pulso`, no `frecuenciaCardiaca`.
      expect(v.pulso, 78);
    });

    test('tolera números que llegan como texto', () {
      // El campo es jsonb libre: nada impide que un cliente escriba "78".
      final v = SignosVitales.fromJson({'pulso': '78', 'temperatura': '36.5'})!;
      expect(v.pulso, 78);
      expect(v.temperatura, 36.5);
    });

    test('conserva las claves que no conoce, no las esconde', () {
      // Esconderlas sería ocultar un dato clínico que un médico anotó.
      final v = SignosVitales.fromJson({
        'pulso': 78,
        'glicemia': 95,
        'notaRara': 'x',
      })!;

      expect(v.otros, {'glicemia': 95, 'notaRara': 'x'});
      expect(v.paraMostrar.map((p) => p.etiqueta), contains('glicemia'));
    });

    test('no manda claves vacías al servidor', () {
      // El backend no valida: mandar nulos dejaría basura en el historial.
      const v = SignosVitales(pulso: 78);
      expect(v.toJson(), {'pulso': 78});
      expect(v.toJson().containsKey('temperatura'), isFalse);
    });

    test('una presión vacía tampoco viaja', () {
      const v = SignosVitales(presionArterial: '', pulso: 60);
      expect(v.toJson().containsKey('presionArterial'), isFalse);
    });

    test('objeto vacío o nulo devuelve null', () {
      expect(SignosVitales.fromJson(null), isNull);
      expect(SignosVitales.fromJson(const {}), isNull);
    });

    test('las unidades se pintan junto al valor', () {
      const v = SignosVitales(pulso: 78, temperatura: 37.2, saturacion: 97);
      final pares = v.paraMostrar;
      expect(pares.map((p) => p.valor), containsAll(['78 lpm', '97 %']));
    });

    test('el orden es el de una toma real', () {
      const v = SignosVitales(presionArterial: '120/80', pulso: 78, peso: 70);
      // Presión primero, peso al final: lo que se mide siempre va arriba.
      expect(v.paraMostrar.first.etiqueta, 'Presión arterial');
      expect(v.paraMostrar.last.etiqueta, 'Peso');
    });
  });

  group('registrar — RF-25, RF-26', () {
    test('camino feliz', () async {
      final r = await HistorialRepository(_ApiFalsa()).registrar(
        const SolicitudConsulta(idCita: 7, diagnostico: 'Faringitis viral'),
      );

      expect(r.esOk, isTrue);
      expect(r.valorONull!.diagnostico, 'Faringitis viral');
      expect(r.valorONull!.idCita, 7);
    });

    test('las recetas van en la misma llamada', () async {
      // Emitirlas aparte dejaría una ventana con la consulta sin su receta.
      final api = _ApiFalsa();
      await HistorialRepository(api).registrar(
        const SolicitudConsulta(
          idCita: 7,
          diagnostico: 'Faringitis',
          recetas: [
            NuevaReceta(
              medicamento: 'Ibuprofeno 400mg',
              dosis: '1 tableta',
              frecuencia: 'Cada 8 horas',
              duracionDias: 5,
            ),
          ],
        ),
      );

      expect(api.registrada!.recetas, hasLength(1));
      expect(api.registrada!.recetas!.first.medicamento, 'Ibuprofeno 400mg');
    });

    test('sin recetas no manda la clave', () async {
      final api = _ApiFalsa();
      await HistorialRepository(
        api,
      ).registrar(const SolicitudConsulta(idCita: 7, diagnostico: 'x'));

      expect(api.registrada!.recetas, isNull);
    });

    test('camino de error: 403 si no es el médico tratante', () async {
      // RNF-06 del lado servidor; el mensaje lo explica sin jerga.
      final r = await HistorialRepository(
        _ApiFalsa(error: _ApiFalsa.http(403, 'No eres el médico de esta cita')),
      ).registrar(const SolicitudConsulta(idCita: 7, diagnostico: 'x'));

      expect(r.failureONull, isA<Prohibido>());
      expect(r.failureONull!.mensaje, contains('médico de esa cita'));
    });

    test('camino de error: 409 conserva el motivo del servidor', () async {
      // Cancelada, ya completada o no asistió: las tres dan 409 y el texto
      // es lo único que dice cuál fue.
      final r = await HistorialRepository(
        _ApiFalsa(error: _ApiFalsa.http(409, 'Esta cita ya fue completada')),
      ).registrar(const SolicitudConsulta(idCita: 7, diagnostico: 'x'));

      expect(r.failureONull, isA<Conflicto>());
      expect(r.failureONull!.mensaje, 'Esta cita ya fue completada');
    });

    test('camino de error: sin conexión', () async {
      final r = await HistorialRepository(
        _ApiFalsa(
          error: DioException(
            requestOptions: RequestOptions(path: '/consultations'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).registrar(const SolicitudConsulta(idCita: 7, diagnostico: 'x'));

      expect(r.failureONull, isA<SinConexion>());
    });
  });

  group('historial — RF-27, RNF-06', () {
    test('camino feliz del paciente', () async {
      final r = await HistorialRepository(_ApiFalsa()).miHistorial();

      final c = r.valorONull!.items.single;
      expect(c.diagnostico, 'Faringitis viral');
      expect(c.tratamiento, 'Reposo e hidratación');
    });

    test('el médico usa la otra ruta', () async {
      final r = await HistorialRepository(_ApiFalsa()).atendidas();
      expect(r.esOk, isTrue);
    });

    test('la fecha se guarda en UTC y se pinta local', () async {
      final r = await HistorialRepository(_ApiFalsa()).miHistorial();
      final c = r.valorONull!.items.single;

      expect(c.registradaUtc.isUtc, isTrue);
      // 14:30Z es 10:30 en Santo Domingo.
      expect(AppTime.hora(c.registradaUtc), '10:30');
    });

    test('traduce vitales y recetas anidadas', () async {
      final r = await HistorialRepository(
        _ApiFalsa(
          vitales: const {'presionArterial': '120/80', 'pulso': 78},
          recetas: const [
            RecetaDto(
              idReceta: 1,
              medicamento: 'Ibuprofeno 400mg',
              dosis: '1 tableta',
              frecuencia: 'Cada 8 horas',
              duracionDias: 5,
            ),
          ],
        ),
      ).miHistorial();

      final c = r.valorONull!.items.single;
      expect(c.tieneVitales, isTrue);
      expect(c.signosVitales!.pulso, 78);
      expect(c.tieneRecetas, isTrue);
      expect(c.recetas.single.pauta, '1 tableta · Cada 8 horas · 5 días');
    });

    test('una consulta sin vitales ni recetas no finge tenerlas', () async {
      final r = await HistorialRepository(_ApiFalsa()).miHistorial();
      final c = r.valorONull!.items.single;

      expect(c.tieneVitales, isFalse);
      expect(c.tieneRecetas, isFalse);
    });

    test('camino de error: 500', () async {
      final r = await HistorialRepository(
        _ApiFalsa(error: _ApiFalsa.http(500, 'boom')),
      ).miHistorial();

      expect(r.failureONull, isA<ErrorServidor>());
    });
  });

  group('Receta', () {
    test('la pauta omite la duración si no la hay', () {
      const r = Receta(
        id: 1,
        medicamento: 'Amoxicilina',
        dosis: '500mg',
        frecuencia: 'Cada 12 horas',
      );
      expect(r.pauta, '500mg · Cada 12 horas');
    });
  });
}
