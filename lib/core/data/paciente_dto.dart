import 'package:freezed_annotation/freezed_annotation.dart';

part 'paciente_dto.freezed.dart';
part 'paciente_dto.g.dart';

/// `GET /api/patients/{id}`.
///
/// A propósito trae solo lo mínimo para pintar un nombre: el backend no
/// devuelve `documentoIdentidad` ni nada clínico en esta ruta —ver
/// `PatientBasicResponseDto` del lado servidor—, y el front no debería pedir
/// más de lo que la pantalla necesita.
@freezed
abstract class PacienteBasicoDto with _$PacienteBasicoDto {
  const factory PacienteBasicoDto({
    required int idPaciente,
    required int idUsuario,
    required String nombres,
    required String apellidos,
  }) = _PacienteBasicoDto;

  factory PacienteBasicoDto.fromJson(Map<String, dynamic> json) =>
      _$PacienteBasicoDtoFromJson(json);
}
