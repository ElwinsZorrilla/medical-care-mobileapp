import 'package:freezed_annotation/freezed_annotation.dart';

// Compartidos con `busqueda` y `citas`, asi que viven en core: un feature no
// importa de otro (REVIEW_GATE 3.3).
export '../../../core/data/medico_dto.dart' show EspecialidadDto, MedicoDto;

part 'perfil_dto.freezed.dart';
part 'perfil_dto.g.dart';

/// `GET /api/patients/me`
@freezed
abstract class PacienteDto with _$PacienteDto {
  const factory PacienteDto({
    required int idPaciente,
    required int idUsuario,
    required String nombres,
    required String apellidos,
    required String documentoIdentidad,
    required String fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) = _PacienteDto;

  factory PacienteDto.fromJson(Map<String, dynamic> json) =>
      _$PacienteDtoFromJson(json);
}

/// `POST /api/patients`
///
/// `documentoIdentidad` y `fechaNacimiento` son obligatorios acá y no
/// aparecen en el DTO de actualización: el backend los fija al crear.
@freezed
abstract class CrearPacienteDto with _$CrearPacienteDto {
  const factory CrearPacienteDto({
    required String nombres,
    required String apellidos,
    required String documentoIdentidad,
    required String fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) = _CrearPacienteDto;

  factory CrearPacienteDto.fromJson(Map<String, dynamic> json) =>
      _$CrearPacienteDtoFromJson(json);
}

/// `PATCH /api/patients/me`
///
/// Todo opcional. **No incluye `documentoIdentidad`**: el backend lo rechaza
/// con 400 por `forbidNonWhitelisted`, así que mandarlo rompería el guardado.
@freezed
abstract class ActualizarPacienteDto with _$ActualizarPacienteDto {
  const factory ActualizarPacienteDto({
    String? nombres,
    String? apellidos,
    String? fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) = _ActualizarPacienteDto;

  factory ActualizarPacienteDto.fromJson(Map<String, dynamic> json) =>
      _$ActualizarPacienteDtoFromJson(json);
}

/// `POST /api/doctors`
@freezed
abstract class CrearMedicoDto with _$CrearMedicoDto {
  const factory CrearMedicoDto({
    required String nombres,
    required String apellidos,
    required String numExequatur,
    String? biografia,
    int? aniosExperiencia,
    num? tarifaConsulta,
  }) = _CrearMedicoDto;

  factory CrearMedicoDto.fromJson(Map<String, dynamic> json) =>
      _$CrearMedicoDtoFromJson(json);
}

/// `PATCH /api/doctors/{id}`
///
/// **No incluye `numExequatur`**: es el identificador legal y el backend no
/// lo acepta en la actualización.
@freezed
abstract class ActualizarMedicoDto with _$ActualizarMedicoDto {
  const factory ActualizarMedicoDto({
    String? nombres,
    String? apellidos,
    String? biografia,
    int? aniosExperiencia,
    num? tarifaConsulta,
  }) = _ActualizarMedicoDto;

  factory ActualizarMedicoDto.fromJson(Map<String, dynamic> json) =>
      _$ActualizarMedicoDtoFromJson(json);
}

/// `PUT /api/doctors/{id}/especialidades`
///
/// El campo es **`especialidadIds`**. La primera versión del contrato decía
/// `idsEspecialidades`; se corrigió contra el spec real.
@freezed
abstract class VincularEspecialidadesDto with _$VincularEspecialidadesDto {
  const factory VincularEspecialidadesDto({
    required List<int> especialidadIds,
  }) = _VincularEspecialidadesDto;

  factory VincularEspecialidadesDto.fromJson(Map<String, dynamic> json) =>
      _$VincularEspecialidadesDtoFromJson(json);
}
