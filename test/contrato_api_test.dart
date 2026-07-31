import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/features/agenda/data/agenda_api.dart';
import 'package:medicare/features/agenda/data/agenda_dto.dart';
import 'package:medicare/features/auth/data/auth_api.dart';
import 'package:medicare/features/auth/data/auth_dto.dart';
import 'package:medicare/features/busqueda/data/busqueda_api.dart';
import 'package:medicare/features/busqueda/data/busqueda_dto.dart';
import 'package:medicare/features/citas/data/citas_api.dart';
import 'package:medicare/features/citas/data/citas_dto.dart';
import 'package:medicare/features/historial/data/historial_api.dart';
import 'package:medicare/features/historial/data/historial_dto.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_dto.dart';

/// Verifica la petición que sale de verdad — ruta, método y query — contra
/// docs/API_CONTRACT.md.
///
/// El resto de las pruebas reemplaza cada `XApi` por un doble que hereda de
/// ella y sobrescribe sus métodos. Eso deja **sin ejecutar** la construcción
/// de la URL y de los parámetros, que es justo la parte que solo falla contra
/// el servidor: una ruta mal escrita, un `page` que debía ser `pagina`, o un
/// filtro nulo que viaja como `especialidadId=null` y devuelve 400.
///
/// Acá no hay dobles de las APIs: se usa la clase real sobre un
/// `HttpClientAdapter` que intercepta el pedido ya armado.
class _Espia implements HttpClientAdapter {
  _Espia(this.respuesta, {this.status = 200});

  /// Lo que devuelve el "servidor". Se arma con `.toJson()` de un DTO real
  /// para no adivinar los nombres de las claves.
  final Object respuesta;
  final int status;

  late RequestOptions pedido;

  Uri get uri => pedido.uri;
  String get metodo => pedido.method;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pedido = options;
    return ResponseBody.fromString(
      jsonEncode(respuesta),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Igual que en producción: `baseUrl` con el prefijo `/api`.
Dio _dio(_Espia espia) =>
    Dio(BaseOptions(baseUrl: 'https://ejemplo.test/api'))
      ..httpClientAdapter = espia;

/// Valores de relleno para los tokens.
///
/// Van como constantes con nombre y no como literales en el sitio de uso: el
/// hook de pre-commit marca un campo de token seguido de una cadena literal
/// como posible secreto en duro (RNF-04). La regla vale la molestia — es la
/// misma que evita que un token real llegue al repositorio por descuido.
const _acceso = 'relleno-acceso';
const _refresco = 'relleno-refresco';

void main() {
  const tokens = AuthTokensDto(accessToken: _acceso, refreshToken: _refresco);
  const usuario = UsuarioDto(
    idUsuario: 1,
    correo: 'a@b.com',
    tipoUsuario: 'PACIENTE',
    estado: 'ACTIVO',
  );
  const medico = MedicoDto(
    idMedico: 7,
    idUsuario: 70,
    nombres: 'Ana',
    apellidos: 'Gómez',
    numExequatur: 'EXQ-1',
    estadoVerificacion: 'VERIFICADO',
  );
  const paciente = PacienteDto(
    idPaciente: 3,
    idUsuario: 30,
    nombres: 'Luis',
    apellidos: 'Pérez',
    documentoIdentidad: '00112345678',
    fechaNacimiento: '1990-05-02',
  );
  const cita = CitaDto(
    idCita: 5,
    idPaciente: 3,
    idMedico: 7,
    fechaHoraInicio: '2026-03-10T13:00:00.000Z',
    fechaHoraFin: '2026-03-10T13:30:00.000Z',
    modalidad: 'PRESENCIAL',
    estado: 'PENDIENTE',
    fechaCreacion: '2026-03-01T10:00:00.000Z',
  );
  const consulta = ConsultaDto(
    idConsulta: 11,
    idCita: 5,
    idPaciente: 3,
    idMedico: 7,
    diagnostico: 'x',
    fechaRegistro: '2026-03-10T14:00:00.000Z',
  );
  const franja = DisponibilidadDto(
    idDisponibilidad: 2,
    idMedico: 7,
    diaSemana: 1,
    horaInicio: '08:00',
    horaFin: '12:00',
    duracionSlotMin: 30,
    modalidad: 'PRESENCIAL',
    activo: true,
  );

  group('el prefijo /api', () {
    test('va en todas las rutas', () async {
      final espia = _Espia(usuario.toJson());
      await AuthApi(_dio(espia)).yo();

      // Sin el prefijo el backend responde 404 en todo. Ver API_CONTRACT §0.
      expect(espia.uri.path, '/api/auth/me');
    });
  });

  group('auth', () {
    test('login manda correo y contrasena, no email/password', () async {
      final espia = _Espia(tokens.toJson());
      await AuthApi(_dio(espia)).login(
        const LoginRequestDto(correo: 'a@b.com', contrasena: 'Secreta.1'),
      );

      expect(espia.metodo, 'POST');
      expect(espia.uri.path, '/api/auth/login');
      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      expect(cuerpo.keys, containsAll(<String>['correo', 'contrasena']));
      // `forbidNonWhitelisted`: un campo de más devuelve 400, así que el
      // cuerpo tiene que ser exactamente el permitido.
      expect(cuerpo.keys, hasLength(2));
    });

    test('registro incluye tipoUsuario', () async {
      final espia = _Espia(tokens.toJson());
      await AuthApi(_dio(espia)).registrar(
        const RegisterRequestDto(
          correo: 'a@b.com',
          contrasena: 'Secreta.1',
          tipoUsuario: 'PACIENTE',
        ),
      );

      expect(espia.uri.path, '/api/auth/register');
      expect(
        (espia.pedido.data! as Map<String, dynamic>)['tipoUsuario'],
        'PACIENTE',
      );
    });
  });

  group('búsqueda — RF-14, RF-15', () {
    test('sin filtro, especialidadId no viaja', () async {
      // Mandarlo en null produce `especialidadId=null` como texto y el
      // backend responde 400: el `?` del spread es lo que se está probando.
      final espia = _Espia({
        'data': [medico.toJson()],
        'total': 1,
        'page': 1,
        'limit': 10,
      });
      await BusquedaApi(_dio(espia)).medicos();

      expect(espia.uri.path, '/api/doctors');
      expect(espia.uri.queryParameters.containsKey('especialidadId'), isFalse);
      expect(espia.uri.queryParameters['page'], '1');
      expect(espia.uri.queryParameters['limit'], '10');
    });

    test('con filtro sí viaja, con ese nombre exacto', () async {
      final espia = _Espia({
        'data': <dynamic>[],
        'total': 0,
        'page': 2,
        'limit': 25,
      });
      await BusquedaApi(
        _dio(espia),
      ).medicos(pagina: 2, limite: 25, especialidadId: 4);

      // No es `especialidad`, ni `idEspecialidad`: `especialidadId`.
      expect(espia.uri.queryParameters['especialidadId'], '4');
      expect(espia.uri.queryParameters['page'], '2');
      expect(espia.uri.queryParameters['limit'], '25');
    });

    test('el catálogo no pagina', () async {
      final espia = _Espia([
        const CatalogoEspecialidadDto(
          idEspecialidad: 1,
          nombre: 'Medicina General',
        ).toJson(),
      ]);
      await BusquedaApi(_dio(espia)).especialidades();

      expect(espia.uri.path, '/api/specialties');
      expect(espia.uri.queryParameters, isEmpty);
    });
  });

  group('agenda', () {
    test('mis franjas no llevan id: sale del token — RF-09', () async {
      final espia = _Espia([franja.toJson()]);
      await AgendaApi(_dio(espia)).misFranjas();

      expect(espia.uri.path, '/api/availability/me');
    });

    test('los turnos van por fecha de calendario — RF-18, RNF-18', () async {
      final espia = _Espia([
        const TurnoDto(
          idDisponibilidad: 2,
          horaInicio: '08:00',
          horaFin: '08:30',
          modalidad: 'PRESENCIAL',
        ).toJson(),
      ]);
      await AgendaApi(_dio(espia)).turnos(idMedico: 7, fecha: '2026-03-10');

      expect(espia.uri.path, '/api/availability/doctors/7/slots');
      expect(espia.uri.queryParameters['fecha'], '2026-03-10');
    });

    test('desactivar es PATCH sobre su propia ruta — RF-17', () async {
      final espia = _Espia(franja.toJson());
      await AgendaApi(_dio(espia)).desactivar(2);

      expect(espia.metodo, 'PATCH');
      expect(espia.uri.path, '/api/availability/2/desactivar');
    });

    test('el PATCH de franja no manda las claves sin tocar', () async {
      // Un `null` en PATCH le diría al backend "borrá este campo".
      final espia = _Espia(franja.toJson());
      await AgendaApi(
        _dio(espia),
      ).actualizar(2, const ActualizarDisponibilidadDto(horaFin: '13:00'));

      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      expect(cuerpo, {'horaFin': '13:00'});
    });
  });

  group('citas', () {
    test('reservar es POST a /appointments — RF-19', () async {
      final espia = _Espia(cita.toJson(), status: 201);
      await CitasApi(_dio(espia)).reservar(
        const CrearCitaDto(
          idMedico: 7,
          fecha: '2026-03-10',
          horaInicio: '09:00',
          modalidad: 'PRESENCIAL',
        ),
      );

      expect(espia.metodo, 'POST');
      expect(espia.uri.path, '/api/appointments');
      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      expect(cuerpo['idMedico'], 7);
      expect(cuerpo['fecha'], '2026-03-10');
      // El paciente no viaja: lo pone el backend desde el token (RF-09).
      expect(cuerpo.containsKey('idPaciente'), isFalse);
    });

    test('paciente y médico leen rutas distintas — RF-24', () async {
      final pagina = {
        'data': [cita.toJson()],
        'total': 1,
        'page': 1,
        'limit': 10,
      };

      final comoPaciente = _Espia(pagina);
      await CitasApi(_dio(comoPaciente)).misCitas();
      expect(comoPaciente.uri.path, '/api/appointments/me');

      final comoMedico = _Espia(pagina);
      await CitasApi(_dio(comoMedico)).miAgenda();
      expect(comoMedico.uri.path, '/api/appointments/agenda');
    });

    test('cancelar manda el motivo — RF-22', () async {
      final espia = _Espia(cita.toJson());
      await CitasApi(_dio(espia)).cancelar(5, 'Me surgió un viaje');

      expect(espia.uri.path, '/api/appointments/5/cancelar');
      expect(
        (espia.pedido.data! as Map<String, dynamic>)['motivo'],
        'Me surgió un viaje',
      );
    });
  });

  group('historial', () {
    test('el listado no admite un id de paciente — RNF-06', () async {
      final espia = _Espia({
        'data': [consulta.toJson()],
        'total': 1,
        'page': 1,
        'limit': 10,
      });
      await HistorialApi(_dio(espia)).miHistorial();

      expect(espia.uri.path, '/api/consultations/me');
      // Solo paginación: no hay forma de expresar "el historial de otro".
      expect(espia.uri.queryParameters.keys, ['page', 'limit']);
    });

    test('el médico lee las que atendió', () async {
      final espia = _Espia({
        'data': <dynamic>[],
        'total': 0,
        'page': 1,
        'limit': 10,
      });
      await HistorialApi(_dio(espia)).atendidas();

      expect(espia.uri.path, '/api/consultations/atendidas');
    });

    test('registrar consulta descarta los opcionales vacíos', () async {
      final espia = _Espia(consulta.toJson(), status: 201);
      await HistorialApi(
        _dio(espia),
      ).registrar(const CrearConsultaDto(idCita: 5, diagnostico: 'Faringitis'));

      expect(espia.uri.path, '/api/consultations');
      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      expect(cuerpo['diagnostico'], 'Faringitis');
      expect(cuerpo.values.contains(null), isFalse);
    });

    test('las recetas van envueltas en su clave — RF-26', () async {
      final espia = _Espia(consulta.toJson(), status: 201);
      await HistorialApi(_dio(espia)).agregarRecetas(11, const [
        CrearRecetaDto(
          medicamento: 'Amoxicilina',
          dosis: '500mg',
          frecuencia: 'c/8h',
        ),
      ]);

      expect(espia.uri.path, '/api/consultations/11/recetas');
      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      expect(cuerpo['recetas'], isA<List<dynamic>>());
      expect(
        (cuerpo['recetas']! as List<dynamic>).single,
        isA<Map<dynamic, dynamic>>(),
      );
    });
  });

  group('perfil — RF-09', () {
    test('el propio perfil se pide sin id', () async {
      final comoPaciente = _Espia(paciente.toJson());
      await PerfilApi(_dio(comoPaciente)).miPerfilPaciente();
      expect(comoPaciente.uri.path, '/api/patients/me');

      final comoMedico = _Espia(medico.toJson());
      await PerfilApi(_dio(comoMedico)).miPerfilMedico();
      expect(comoMedico.uri.path, '/api/doctors/me');
    });

    test('el de otro médico sí lleva id: es público', () async {
      final espia = _Espia(medico.toJson());
      await PerfilApi(_dio(espia)).perfilMedicoPorId(7);

      expect(espia.uri.path, '/api/doctors/7');
    });

    test('el PATCH de paciente solo manda lo tocado', () async {
      final espia = _Espia(paciente.toJson());
      await PerfilApi(
        _dio(espia),
      ).actualizarPerfilPaciente(const ActualizarPacienteDto(direccion: 'X'));

      expect(espia.metodo, 'PATCH');
      expect(espia.uri.path, '/api/patients/me');
      expect(espia.pedido.data, {'direccion': 'X'});
    });

    test('vincular especialidades es PUT y usa especialidadIds', () async {
      // El nombre correcto se verificó contra /docs-json en F00: no es
      // `especialidades` ni `idsEspecialidad`.
      final espia = _Espia(medico.toJson());
      await PerfilApi(_dio(espia)).vincularEspecialidades(7, const [1, 4]);

      expect(espia.metodo, 'PUT');
      expect(espia.uri.path, '/api/doctors/7/especialidades');
      expect(espia.pedido.data, {
        'especialidadIds': [1, 4],
      });
    });

    test('crear perfil de médico es POST sin id', () async {
      final espia = _Espia(medico.toJson(), status: 201);
      await PerfilApi(_dio(espia)).crearPerfilMedico(
        const CrearMedicoDto(
          nombres: 'Ana',
          apellidos: 'Gómez',
          numExequatur: 'EXQ-1',
        ),
      );

      expect(espia.metodo, 'POST');
      expect(espia.uri.path, '/api/doctors');
    });

    test('crear perfil de paciente exige documento y nacimiento', () async {
      final espia = _Espia(paciente.toJson(), status: 201);
      await PerfilApi(_dio(espia)).crearPerfilPaciente(
        const CrearPacienteDto(
          nombres: 'Luis',
          apellidos: 'Pérez',
          documentoIdentidad: '00112345678',
          fechaNacimiento: '1990-05-02',
        ),
      );

      expect(espia.uri.path, '/api/patients');
      final cuerpo = espia.pedido.data! as Map<String, dynamic>;
      // Fecha de calendario, sin hora ni zona: no pasa por AppTime (RNF-18).
      expect(cuerpo['fechaNacimiento'], '1990-05-02');
    });

    test('el PATCH de médico va a su id', () async {
      final espia = _Espia(medico.toJson());
      await PerfilApi(
        _dio(espia),
      ).actualizarPerfilMedico(7, const ActualizarMedicoDto(biografia: 'Hola'));

      expect(espia.uri.path, '/api/doctors/7');
      expect(espia.pedido.data, {'biografia': 'Hola'});
    });
  });
}
