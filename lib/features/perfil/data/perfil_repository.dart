import 'package:dio/dio.dart';

import '../../../core/domain/especialidad.dart';
import '../../../core/domain/fecha_calendario.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/network/result.dart';
import '../domain/perfil.dart';
import 'perfil_api.dart';
import 'perfil_dto.dart';

/// Traduce DTO ↔ entidad y `DioException` → [Failure].
class PerfilRepository {
  const PerfilRepository(this._api);

  final PerfilApi _api;

  // ── Paciente — RF-07 ────────────────────────────────────────────────────

  /// Devuelve `null` si el usuario aún no creó su perfil.
  ///
  /// El backend responde **404** en ese caso, y eso no es un error: es el
  /// estado normal de alguien que acaba de registrarse. Mostrarle "no
  /// encontramos lo que buscabas" sería culparlo de no haber hecho algo que
  /// nadie le pidió todavía.
  Future<Result<PerfilPaciente?>> miPerfilPaciente() =>
      _envolverOpcional(() async => _aPaciente(await _api.miPerfilPaciente()));

  Future<Result<PerfilPaciente>> crearPerfilPaciente({
    required String nombres,
    required String apellidos,
    required String documentoIdentidad,
    required FechaCalendario fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) => _envolver(
    () async => _aPaciente(
      await _api.crearPerfilPaciente(
        CrearPacienteDto(
          nombres: nombres,
          apellidos: apellidos,
          documentoIdentidad: documentoIdentidad,
          fechaNacimiento: fechaNacimiento.toApi(),
          sexo: sexo,
          direccion: direccion,
          tipoSangre: tipoSangre,
          alergias: alergias,
          seguroMedico: seguroMedico,
        ),
      ),
    ),
    mensaje409: 'Ya tienes un perfil creado.',
  );

  /// RF-10 — solo el propio.
  ///
  /// No recibe id: el backend resuelve el paciente desde el token. No hay
  /// forma de pedir la actualización de otro.
  Future<Result<PerfilPaciente>> actualizarPerfilPaciente({
    String? nombres,
    String? apellidos,
    FechaCalendario? fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) => _envolver(
    () async => _aPaciente(
      await _api.actualizarPerfilPaciente(
        ActualizarPacienteDto(
          nombres: nombres,
          apellidos: apellidos,
          fechaNacimiento: fechaNacimiento?.toApi(),
          sexo: sexo,
          direccion: direccion,
          tipoSangre: tipoSangre,
          alergias: alergias,
          seguroMedico: seguroMedico,
        ),
      ),
    ),
  );

  // ── Médico — RF-08, RF-11 ───────────────────────────────────────────────

  Future<Result<PerfilMedico?>> miPerfilMedico() =>
      _envolverOpcional(() async => _aMedico(await _api.miPerfilMedico()));

  Future<Result<PerfilMedico>> perfilMedicoPorId(int idMedico) =>
      _envolver(() async => _aMedico(await _api.perfilMedicoPorId(idMedico)));

  Future<Result<PerfilMedico>> crearPerfilMedico({
    required String nombres,
    required String apellidos,
    required String numExequatur,
    String? biografia,
    int? aniosExperiencia,
    double? tarifaConsulta,
  }) => _envolver(
    () async => _aMedico(
      await _api.crearPerfilMedico(
        CrearMedicoDto(
          nombres: nombres,
          apellidos: apellidos,
          numExequatur: numExequatur,
          biografia: biografia,
          aniosExperiencia: aniosExperiencia,
          tarifaConsulta: tarifaConsulta,
        ),
      ),
    ),
    mensaje409: 'Ya tienes un perfil de médico creado.',
  );

  /// RF-10 — el backend responde 403 si el id no es el del titular.
  Future<Result<PerfilMedico>> actualizarPerfilMedico({
    required int idMedico,
    String? nombres,
    String? apellidos,
    String? biografia,
    int? aniosExperiencia,
    double? tarifaConsulta,
  }) => _envolver(
    () async => _aMedico(
      await _api.actualizarPerfilMedico(
        idMedico,
        ActualizarMedicoDto(
          nombres: nombres,
          apellidos: apellidos,
          biografia: biografia,
          aniosExperiencia: aniosExperiencia,
          tarifaConsulta: tarifaConsulta,
        ),
      ),
    ),
    mensaje403: 'Solo puedes editar tu propio perfil.',
  );

  Future<Result<PerfilMedico>> vincularEspecialidades({
    required int idMedico,
    required List<int> especialidadIds,
  }) => _envolver(
    () async =>
        _aMedico(await _api.vincularEspecialidades(idMedico, especialidadIds)),
    mensaje403: 'Solo puedes editar tu propio perfil.',
  );

  // ── Traducción ──────────────────────────────────────────────────────────

  PerfilPaciente _aPaciente(PacienteDto dto) => PerfilPaciente(
    idPaciente: dto.idPaciente,
    idUsuario: dto.idUsuario,
    nombres: dto.nombres,
    apellidos: dto.apellidos,
    documentoIdentidad: dto.documentoIdentidad,
    // Si el backend mandara una fecha con forma inesperada, es preferible
    // una fecha vacía y visible que una excepción que tumbe la pantalla de
    // perfil entera.
    fechaNacimiento:
        FechaCalendario.parse(dto.fechaNacimiento) ??
        const FechaCalendario(1900, 1, 1),
    sexo: dto.sexo,
    direccion: dto.direccion,
    tipoSangre: dto.tipoSangre,
    alergias: dto.alergias,
    seguroMedico: dto.seguroMedico,
  );

  PerfilMedico _aMedico(MedicoDto dto) => PerfilMedico(
    idMedico: dto.idMedico,
    idUsuario: dto.idUsuario,
    nombres: dto.nombres,
    apellidos: dto.apellidos,
    numExequatur: dto.numExequatur,
    estadoVerificacion: EstadoVerificacion.fromApi(dto.estadoVerificacion),
    especialidades: dto.especialidades
        .map(
          (e) => Especialidad(
            id: e.idEspecialidad,
            nombre: e.nombre,
            descripcion: e.descripcion,
            urlIcono: e.urlIcono,
          ),
        )
        .toList(),
    biografia: dto.biografia,
    aniosExperiencia: dto.aniosExperiencia,
    tarifaConsulta: dto.tarifaConsulta?.toDouble(),
  );

  /// Igual que [_envolver], pero un 404 se traduce a "todavía no existe".
  Future<Result<T?>> _envolverOpcional<T>(Future<T> Function() peticion) async {
    try {
      return Ok(await peticion());
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const Ok(null);
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }

  Future<Result<T>> _envolver<T>(
    Future<T> Function() peticion, {
    String? mensaje409,
    String? mensaje403,
  }) async {
    try {
      return Ok(await peticion());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 409 && mensaje409 != null) {
        return Fallo(Conflicto(mensaje409, mensajeServidor: mensaje409));
      }
      if (status == 403 && mensaje403 != null) {
        return Fallo(Prohibido(mensaje403));
      }
      return Fallo(FailureMapper.desdeDio(e));
    } on ArgumentError catch (e) {
      // Estado de verificación desconocido: el backend agregó un valor que
      // la app no mapea. Falla ruidoso en vez de pintar el badge equivocado.
      return Fallo(ErrorInesperado(e.message.toString()));
    }
  }
}
