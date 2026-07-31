/// Signos vitales de una consulta — RF-25.
///
/// ## Por qué existe este tipo
///
/// El backend guarda esto como **`jsonb` libre** (`Record<string, unknown>`,
/// sin validación). Nada impide que un cliente escriba `presion` y otro
/// `presionArterial`: los dos se aceptan, y el historial del paciente queda
/// con claves distintas para el mismo dato. Consultarlo después es
/// imposible, y comparar la presión de marzo con la de agosto deja de
/// funcionar sin que nadie note cuándo se rompió.
///
/// Como el servidor no impone forma, **la impone la app**. Las claves
/// canónicas son las del ejemplo del propio spec.
class SignosVitales {
  const SignosVitales({
    this.presionArterial,
    this.temperatura,
    this.pulso,
    this.saturacion,
    this.peso,
    this.talla,
    this.otros = const {},
  });

  /// `"120/80"` — se guarda como texto porque son dos números con barra.
  final String? presionArterial;

  /// En grados Celsius.
  final double? temperatura;

  /// Latidos por minuto. La clave del backend es **`pulso`**, no
  /// `frecuenciaCardiaca` como decía el contrato inferido antes de F00.
  final int? pulso;

  /// Saturación de oxígeno, en porcentaje.
  final int? saturacion;

  /// En kilogramos.
  final double? peso;

  /// En centímetros.
  final int? talla;

  /// Claves que la app no conoce.
  ///
  /// Se conservan y se muestran a propósito. Si otro cliente escribió algo
  /// que esta versión no mapea, **esconderlo sería ocultar un dato clínico**
  /// que un médico anotó. Se pinta con su clave cruda antes que desaparecer.
  final Map<String, Object?> otros;

  static const _clavesConocidas = {
    'presionArterial',
    'temperatura',
    'pulso',
    'saturacion',
    'peso',
    'talla',
  };

  bool get estaVacio =>
      presionArterial == null &&
      temperatura == null &&
      pulso == null &&
      saturacion == null &&
      peso == null &&
      talla == null &&
      otros.isEmpty;

  static SignosVitales? fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;

    double? aDouble(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    int? aInt(Object? v) => switch (v) {
      final num n => n.round(),
      final String s => int.tryParse(s),
      _ => null,
    };

    return SignosVitales(
      presionArterial: json['presionArterial']?.toString(),
      temperatura: aDouble(json['temperatura']),
      pulso: aInt(json['pulso']),
      saturacion: aInt(json['saturacion']),
      peso: aDouble(json['peso']),
      talla: aInt(json['talla']),
      otros: {
        for (final e in json.entries)
          if (!_clavesConocidas.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Solo las claves con valor: el backend no valida, así que mandar nulos
  /// dejaría basura en el `jsonb` del historial.
  Map<String, Object?> toJson() => {
    if (presionArterial != null && presionArterial!.isNotEmpty)
      'presionArterial': presionArterial,
    if (temperatura != null) 'temperatura': temperatura,
    if (pulso != null) 'pulso': pulso,
    if (saturacion != null) 'saturacion': saturacion,
    if (peso != null) 'peso': peso,
    if (talla != null) 'talla': talla,
    ...otros,
  };

  /// Pares etiqueta/valor listos para pintar, en orden clínico y con unidad.
  ///
  /// El orden es el de una toma real: primero lo que se mide siempre.
  List<({String etiqueta, String valor})> get paraMostrar => [
    if (presionArterial != null)
      (etiqueta: 'Presión arterial', valor: presionArterial!),
    if (pulso != null) (etiqueta: 'Pulso', valor: '$pulso lpm'),
    if (temperatura != null)
      (etiqueta: 'Temperatura', valor: '$temperatura °C'),
    if (saturacion != null) (etiqueta: 'Saturación', valor: '$saturacion %'),
    if (peso != null) (etiqueta: 'Peso', valor: '$peso kg'),
    if (talla != null) (etiqueta: 'Talla', valor: '$talla cm'),
    for (final e in otros.entries)
      (etiqueta: e.key, valor: e.value?.toString() ?? '—'),
  ];
}

/// Receta emitida — RF-26.
class Receta {
  const Receta({
    required this.id,
    required this.medicamento,
    required this.dosis,
    required this.frecuencia,
    this.duracionDias,
    this.indicaciones,
  });

  final int id;
  final String medicamento;
  final String dosis;
  final String frecuencia;

  /// El campo del backend es **`duracionDias`** (número), no `duracion`.
  final int? duracionDias;

  final String? indicaciones;

  /// `1 tableta · Cada 8 horas · 5 días`
  String get pauta => [
    dosis,
    frecuencia,
    if (duracionDias != null) '$duracionDias días',
  ].join(' · ');
}

/// Consulta registrada — RF-25, RF-27.
class Consulta {
  const Consulta({
    required this.id,
    required this.idCita,
    required this.idPaciente,
    required this.idMedico,
    required this.diagnostico,
    required this.registradaUtc,
    this.tratamiento,
    this.observaciones,
    this.signosVitales,
    this.recetas = const [],
  });

  final int id;
  final int idCita;
  final int idPaciente;
  final int idMedico;

  /// Lo único obligatorio además de la cita.
  final String diagnostico;

  final DateTime registradaUtc;
  final String? tratamiento;
  final String? observaciones;
  final SignosVitales? signosVitales;
  final List<Receta> recetas;

  bool get tieneRecetas => recetas.isNotEmpty;
  bool get tieneVitales => signosVitales?.estaVacio == false;
}

/// Qué mandar al registrar — RF-25, RF-26.
///
/// Las recetas pueden ir **en la misma llamada**: `CreateConsultationDto`
/// acepta `recetas[]`. Emitirlas aparte con `POST /consultations/:id/recetas`
/// dejaría una ventana en la que la consulta existe sin su receta.
class SolicitudConsulta {
  const SolicitudConsulta({
    required this.idCita,
    required this.diagnostico,
    this.tratamiento,
    this.observaciones,
    this.signosVitales,
    this.recetas = const [],
  });

  final int idCita;
  final String diagnostico;
  final String? tratamiento;
  final String? observaciones;
  final SignosVitales? signosVitales;
  final List<NuevaReceta> recetas;
}

/// Receta a emitir, todavía sin id.
class NuevaReceta {
  const NuevaReceta({
    required this.medicamento,
    required this.dosis,
    required this.frecuencia,
    this.duracionDias,
    this.indicaciones,
  });

  final String medicamento;
  final String dosis;
  final String frecuencia;
  final int? duracionDias;
  final String? indicaciones;
}
