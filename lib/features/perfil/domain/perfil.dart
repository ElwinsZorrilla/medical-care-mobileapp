import 'package:flutter/widgets.dart';

import '../../../core/domain/especialidad.dart';
import '../../../core/domain/fecha_calendario.dart';
import '../../../core/theme/tokens.dart';

/// Estado de verificación del médico — RF-11.
///
/// Lo mueve un administrador del lado servidor: **no hay endpoint que lo
/// cambie desde la app**. Por eso la UI lo muestra y lo explica, pero no
/// ofrece ninguna acción para modificarlo.
enum EstadoVerificacion {
  pendiente('PENDIENTE'),
  verificado('VERIFICADO'),
  rechazado('RECHAZADO');

  const EstadoVerificacion(this.apiValue);

  final String apiValue;

  static EstadoVerificacion fromApi(String value) {
    for (final e in EstadoVerificacion.values) {
      if (e.apiValue == value) return e;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Estado de verificación desconocido. Esperados: '
          '${EstadoVerificacion.values.map((e) => e.apiValue).join(', ')}',
    );
  }

  String get etiqueta => switch (this) {
    EstadoVerificacion.pendiente => 'EN REVISIÓN',
    EstadoVerificacion.verificado => 'VERIFICADO',
    EstadoVerificacion.rechazado => 'RECHAZADO',
  };

  /// RF-11 pide que el estado sea "visible **y explicado**".
  ///
  /// Un badge que solo diga "PENDIENTE" deja al médico sin saber si tiene que
  /// hacer algo, cuánto va a tardar, o si puede trabajar mientras tanto. Cada
  /// estado dice qué significa y qué sigue.
  String get explicacion => switch (this) {
    EstadoVerificacion.pendiente =>
      'Estamos validando tu exequátur. Mientras tanto tu perfil no aparece '
          'en las búsquedas de pacientes.',
    EstadoVerificacion.verificado =>
      'Tu exequátur fue validado. Los pacientes ya pueden encontrarte y '
          'reservar contigo.',
    EstadoVerificacion.rechazado =>
      'No pudimos validar tu exequátur. Escribe a soporte para revisar los '
          'datos de tu perfil.',
  };

  /// Mismo criterio que el riel de estado: color + glifo + etiqueta, nunca
  /// color solo.
  String get glifo => switch (this) {
    EstadoVerificacion.pendiente => '○',
    EstadoVerificacion.verificado => '●',
    EstadoVerificacion.rechazado => '✕',
  };

  Color color(Brightness brillo) {
    final oscuro = brillo == Brightness.dark;
    return switch (this) {
      EstadoVerificacion.pendiente =>
        oscuro ? AppColors.ambarDark : AppColors.ambar,
      EstadoVerificacion.verificado =>
        oscuro ? AppColors.verdeDark : AppColors.verde,
      EstadoVerificacion.rechazado =>
        oscuro ? AppColors.granateDark : AppColors.granate,
    };
  }
}

/// Perfil de paciente — RF-07.
class PerfilPaciente {
  const PerfilPaciente({
    required this.idPaciente,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.documentoIdentidad,
    required this.fechaNacimiento,
    this.sexo,
    this.direccion,
    this.tipoSangre,
    this.alergias,
    this.seguroMedico,
  });

  final int idPaciente;
  final int idUsuario;
  final String nombres;
  final String apellidos;

  /// Identificador legal. El backend lo fija al crear el perfil y
  /// `UpdatePatientDto` no lo incluye: **no es editable**.
  final String documentoIdentidad;

  /// Fecha de calendario, no un instante. Ver [FechaCalendario].
  final FechaCalendario fechaNacimiento;

  final String? sexo;
  final String? direccion;
  final String? tipoSangre;

  /// El backend la guarda como **texto libre**, no como lista.
  final String? alergias;

  final String? seguroMedico;

  String get nombreCompleto => '$nombres $apellidos';
}

/// Perfil de médico — RF-08, RF-11.
class PerfilMedico {
  const PerfilMedico({
    required this.idMedico,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.numExequatur,
    required this.estadoVerificacion,
    this.especialidades = const [],
    this.biografia,
    this.aniosExperiencia,
    this.tarifaConsulta,
  });

  final int idMedico;
  final int idUsuario;
  final String nombres;
  final String apellidos;

  /// Identificador legal del médico. Igual que el documento del paciente,
  /// el backend lo fija al crear y `UpdateDoctorDto` no lo acepta.
  final String numExequatur;

  final EstadoVerificacion estadoVerificacion;
  final List<Especialidad> especialidades;
  final String? biografia;
  final int? aniosExperiencia;
  final double? tarifaConsulta;

  String get nombreCompleto => 'Dr. $nombres $apellidos';

  /// Si puede recibir reservas.
  bool get estaVerificado =>
      estadoVerificacion == EstadoVerificacion.verificado;
}
