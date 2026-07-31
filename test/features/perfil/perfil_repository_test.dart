import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/fecha_calendario.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_dto.dart';
import 'package:medicare/features/perfil/data/perfil_repository.dart';
import 'package:medicare/features/perfil/domain/perfil.dart';

class _ApiFalsa extends PerfilApi {
  _ApiFalsa({this.error, this.estadoMedico = 'PENDIENTE'}) : super(Dio());

  final DioException? error;
  final String estadoMedico;

  ActualizarPacienteDto? patchPacienteRecibido;
  ActualizarMedicoDto? patchMedicoRecibido;
  List<int>? especialidadesRecibidas;

  static DioException httpError(int status) {
    final o = RequestOptions(path: '/patients/me');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  static const _paciente = PacienteDto(
    idPaciente: 3,
    idUsuario: 9,
    nombres: 'Juana',
    apellidos: 'Pérez',
    documentoIdentidad: '00112345678',
    fechaNacimiento: '1990-08-01',
    sexo: 'F',
    tipoSangre: 'O+',
    alergias: 'Penicilina',
  );

  @override
  Future<PacienteDto> miPerfilPaciente() async {
    if (error != null) throw error!;
    return _paciente;
  }

  @override
  Future<PacienteDto> crearPerfilPaciente(CrearPacienteDto body) async {
    if (error != null) throw error!;
    return _paciente;
  }

  @override
  Future<PacienteDto> actualizarPerfilPaciente(
    ActualizarPacienteDto body,
  ) async {
    patchPacienteRecibido = body;
    if (error != null) throw error!;
    return _paciente;
  }

  MedicoDto get _medico => MedicoDto(
    idMedico: 5,
    idUsuario: 11,
    nombres: 'Alejandra',
    apellidos: 'Peña',
    numExequatur: '24-1877',
    estadoVerificacion: estadoMedico,
    especialidades: const [
      EspecialidadDto(idEspecialidad: 4, nombre: 'Cardiología'),
    ],
    tarifaConsulta: 1500,
    aniosExperiencia: 12,
  );

  @override
  Future<MedicoDto> miPerfilMedico() async {
    if (error != null) throw error!;
    return _medico;
  }

  @override
  Future<MedicoDto> perfilMedicoPorId(int idMedico) async {
    if (error != null) throw error!;
    return _medico;
  }

  @override
  Future<MedicoDto> crearPerfilMedico(CrearMedicoDto body) async {
    if (error != null) throw error!;
    return _medico;
  }

  @override
  Future<MedicoDto> actualizarPerfilMedico(
    int idMedico,
    ActualizarMedicoDto body,
  ) async {
    patchMedicoRecibido = body;
    if (error != null) throw error!;
    return _medico;
  }

  @override
  Future<MedicoDto> vincularEspecialidades(
    int idMedico,
    List<int> especialidadIds,
  ) async {
    especialidadesRecibidas = especialidadIds;
    if (error != null) throw error!;
    return _medico;
  }
}

void main() {
  group('perfil de paciente — RF-07', () {
    test('camino feliz: traduce el DTO a entidad', () async {
      final r = await PerfilRepository(_ApiFalsa()).miPerfilPaciente();

      final p = r.valorONull!;
      expect(p.nombreCompleto, 'Juana Pérez');
      expect(p.documentoIdentidad, '00112345678');
      expect(p.tipoSangre, 'O+');
      // Alergias es texto libre en el backend, no una lista.
      expect(p.alergias, 'Penicilina');
    });

    test('la fecha de nacimiento no se corre por zona horaria', () async {
      final r = await PerfilRepository(_ApiFalsa()).miPerfilPaciente();
      // 1990-08-01 tiene que seguir siendo el 1, no el 31 de julio.
      expect(r.valorONull!.fechaNacimiento, const FechaCalendario(1990, 8, 1));
    });

    test('404 significa "todavía no lo creó", no un error', () async {
      // Es el estado normal de alguien que acaba de registrarse. Mostrarle un
      // error sería culparlo de no haber hecho algo que nadie le pidió.
      final r = await PerfilRepository(
        _ApiFalsa(error: _ApiFalsa.httpError(404)),
      ).miPerfilPaciente();

      expect(r.esOk, isTrue);
      expect(r.valorONull, isNull);
    });

    test('camino de error: 500 sí se reporta', () async {
      final r = await PerfilRepository(
        _ApiFalsa(error: _ApiFalsa.httpError(500)),
      ).miPerfilPaciente();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorServidor>());
    });

    test('camino de error: 409 al crear un perfil que ya existe', () async {
      final r =
          await PerfilRepository(
            _ApiFalsa(error: _ApiFalsa.httpError(409)),
          ).crearPerfilPaciente(
            nombres: 'J',
            apellidos: 'P',
            documentoIdentidad: '001',
            fechaNacimiento: const FechaCalendario(1990, 1, 1),
          );

      expect(r.failureONull, isA<Conflicto>());
      expect(r.failureONull!.mensaje, contains('Ya tienes un perfil'));
    });
  });

  group('actualización — RF-10', () {
    test('el PATCH del paciente no manda el documento', () async {
      // `UpdatePatientDto` del backend no lo incluye y corre con
      // forbidNonWhitelisted: mandarlo devolvería 400.
      final api = _ApiFalsa();
      await PerfilRepository(api).actualizarPerfilPaciente(nombres: 'Ana');

      final json = api.patchPacienteRecibido!.toJson();
      expect(json.containsKey('documentoIdentidad'), isFalse);
    });

    test('el PATCH del médico no manda el exequátur', () async {
      final api = _ApiFalsa();
      await PerfilRepository(
        api,
      ).actualizarPerfilMedico(idMedico: 5, biografia: 'x');

      final json = api.patchMedicoRecibido!.toJson();
      expect(json.containsKey('numExequatur'), isFalse);
    });

    test('403 al editar un perfil ajeno', () async {
      final r = await PerfilRepository(
        _ApiFalsa(error: _ApiFalsa.httpError(403)),
      ).actualizarPerfilMedico(idMedico: 99, nombres: 'X');

      expect(r.failureONull, isA<Prohibido>());
      expect(r.failureONull!.mensaje, contains('tu propio perfil'));
    });
  });

  group('perfil de médico — RF-08, RF-11', () {
    test('camino feliz: mapea estado y especialidades', () async {
      final r = await PerfilRepository(
        _ApiFalsa(estadoMedico: 'VERIFICADO'),
      ).miPerfilMedico();

      final m = r.valorONull!;
      expect(m.nombreCompleto, 'Dr. Alejandra Peña');
      expect(m.numExequatur, '24-1877');
      expect(m.estadoVerificacion, EstadoVerificacion.verificado);
      expect(m.estaVerificado, isTrue);
      expect(m.especialidades.single.nombre, 'Cardiología');
      expect(m.tarifaConsulta, 1500.0);
    });

    test('camino de error: estado desconocido falla ruidoso', () async {
      // Pintar el badge equivocado sería peor: un médico rechazado creyendo
      // que está verificado esperaría pacientes que nunca llegan.
      final r = await PerfilRepository(
        _ApiFalsa(estadoMedico: 'EN_TRAMITE'),
      ).miPerfilMedico();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorInesperado>());
    });

    test('vincular especialidades manda especialidadIds', () async {
      // El contrato inicial decía `idsEspecialidades`; el nombre real es al
      // revés y se corrigió contra el spec.
      final api = _ApiFalsa();
      await PerfilRepository(
        api,
      ).vincularEspecialidades(idMedico: 5, especialidadIds: [1, 4]);

      expect(api.especialidadesRecibidas, [1, 4]);
    });
  });

  group('EstadoVerificacion — RF-11', () {
    test('mapea los tres valores del backend', () {
      expect(
        EstadoVerificacion.fromApi('PENDIENTE'),
        EstadoVerificacion.pendiente,
      );
      expect(
        EstadoVerificacion.fromApi('VERIFICADO'),
        EstadoVerificacion.verificado,
      );
      expect(
        EstadoVerificacion.fromApi('RECHAZADO'),
        EstadoVerificacion.rechazado,
      );
    });

    test('cada estado se explica, no solo se etiqueta', () {
      // RF-11 pide que sea visible **y explicado**. Un badge que solo diga
      // "PENDIENTE" deja al médico sin saber si tiene que hacer algo.
      for (final e in EstadoVerificacion.values) {
        expect(e.explicacion.length, greaterThan(40), reason: e.name);
        expect(e.etiqueta, isNotEmpty);
        expect(e.glifo, isNotEmpty);
      }
    });

    test('los tres glifos son distintos: no comunica solo por color', () {
      final glifos = EstadoVerificacion.values.map((e) => e.glifo).toSet();
      expect(glifos.length, 3);
    });

    test('el color se adapta al tema', () {
      for (final e in EstadoVerificacion.values) {
        expect(
          e.color(Brightness.light),
          isNot(e.color(Brightness.dark)),
          reason: e.name,
        );
      }
    });
  });
}
