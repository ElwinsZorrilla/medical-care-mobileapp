import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/fecha_calendario.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/perfil_api.dart';
import '../../data/perfil_repository.dart';
import '../../domain/perfil.dart';

part 'perfil_provider.g.dart';

@Riverpod(keepAlive: true)
PerfilRepository perfilRepository(Ref ref) =>
    PerfilRepository(PerfilApi(ref.watch(dioClienteProvider)));

/// Perfil del paciente autenticado — RF-07.
///
/// `null` significa "todavía no lo creó", que es distinto de un error. La
/// pantalla lo usa para ofrecer crearlo en vez de mostrar un fallo.
@riverpod
Future<PerfilPaciente?> miPerfilPaciente(Ref ref) async {
  final resultado = await ref
      .watch(perfilRepositoryProvider)
      .miPerfilPaciente();
  return switch (resultado) {
    Ok(:final valor) => valor,
    // Se relanza para que `AsyncValue` capture el error y la pantalla pueda
    // pintar el estado de error con su mensaje.
    Fallo(:final failure) => throw failure,
  };
}

/// Perfil del médico autenticado — RF-08, RF-11.
@riverpod
Future<PerfilMedico?> miPerfilMedico(Ref ref) async {
  final resultado = await ref.watch(perfilRepositoryProvider).miPerfilMedico();
  return switch (resultado) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}

/// Perfil público de un médico, para la búsqueda y el detalle de cita.
@riverpod
Future<PerfilMedico> perfilMedicoPorId(Ref ref, int idMedico) async {
  final resultado = await ref
      .watch(perfilRepositoryProvider)
      .perfilMedicoPorId(idMedico);
  return switch (resultado) {
    Ok(:final valor) => valor,
    Fallo(:final failure) => throw failure,
  };
}

/// RF-10 — crear o actualizar el perfil propio.
///
/// Existia la capa de datos con sus pruebas desde F05 y **ninguna pantalla la
/// llamaba**: F15 lo destapo recorriendo lib/ en busca de metodos publicos sin
/// consumidor. La matriz daba RF-10 por cumplido y no habia donde editar.
///
/// No hay `idPaciente` ni `idUsuario` en ninguna firma: el backend resuelve el
/// titular desde el token (RF-09). Para el medico si hace falta su `idMedico`,
/// que sale de su propio perfil ya cargado, no de un campo que el cliente
/// pueda elegir.
@riverpod
class EdicionPerfil extends _$EdicionPerfil {
  @override
  void build() {}

  /// Devuelve el fallo si lo hubo, o `null` si salio bien.
  ///
  /// Elige crear o actualizar segun exista ya el perfil. Son endpoints
  /// distintos —`POST /patients` y `PATCH /patients/me`— y confundirlos da un
  /// 409 por documento repetido.
  Future<Failure?> guardarPaciente({
    required bool existe,
    required String nombres,
    required String apellidos,
    required String documentoIdentidad,
    required FechaCalendario fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) async {
    final repo = ref.read(perfilRepositoryProvider);
    final r = existe
        ? await repo.actualizarPerfilPaciente(
            nombres: nombres,
            apellidos: apellidos,
            fechaNacimiento: fechaNacimiento,
            sexo: sexo,
            direccion: direccion,
            tipoSangre: tipoSangre,
            alergias: alergias,
            seguroMedico: seguroMedico,
          )
        : await repo.crearPerfilPaciente(
            nombres: nombres,
            apellidos: apellidos,
            documentoIdentidad: documentoIdentidad,
            fechaNacimiento: fechaNacimiento,
            sexo: sexo,
            direccion: direccion,
            tipoSangre: tipoSangre,
            alergias: alergias,
            seguroMedico: seguroMedico,
          );

    if (r.esOk) ref.invalidate(miPerfilPacienteProvider);
    return r.failureONull;
  }

  Future<Failure?> guardarMedico({
    required int? idMedico,
    required String nombres,
    required String apellidos,
    required String numExequatur,
    String? biografia,
    int? aniosExperiencia,
    double? tarifaConsulta,
  }) async {
    final repo = ref.read(perfilRepositoryProvider);
    final r = idMedico == null
        ? await repo.crearPerfilMedico(
            nombres: nombres,
            apellidos: apellidos,
            numExequatur: numExequatur,
            biografia: biografia,
            aniosExperiencia: aniosExperiencia,
            tarifaConsulta: tarifaConsulta,
          )
        : await repo.actualizarPerfilMedico(
            idMedico: idMedico,
            nombres: nombres,
            apellidos: apellidos,
            biografia: biografia,
            aniosExperiencia: aniosExperiencia,
            tarifaConsulta: tarifaConsulta,
          );

    if (r.esOk) ref.invalidate(miPerfilMedicoProvider);
    return r.failureONull;
  }
}
