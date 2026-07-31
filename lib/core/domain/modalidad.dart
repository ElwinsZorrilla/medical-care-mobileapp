/// Modalidad de una **cita** — `PRESENCIAL` o `VIRTUAL`.
///
/// Va en `core/` porque la comparten `agenda` (al reservar) y `citas` (al
/// listar y cancelar). Es la lección de F06: lo que dos features necesitan
/// sube antes de que uno importe del otro, no después.
enum ModalidadCita {
  presencial('PRESENCIAL'),
  virtual('VIRTUAL');

  const ModalidadCita(this.apiValue);

  final String apiValue;

  static ModalidadCita fromApi(String value) {
    for (final m in ModalidadCita.values) {
      if (m.apiValue == value) return m;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Modalidad de cita desconocida. Esperadas: '
          '${ModalidadCita.values.map((m) => m.apiValue).join(', ')}',
    );
  }

  String get etiqueta => switch (this) {
    ModalidadCita.presencial => 'Presencial',
    ModalidadCita.virtual => 'Virtual',
  };
}

/// Modalidad de una **franja de disponibilidad**.
///
/// Tiene un valor más que la cita: `AMBAS`. Un médico puede abrir una franja
/// que acepte las dos, pero la cita concreta siempre es una sola.
///
/// Confundirlas cuesta un 409: reservar `VIRTUAL` en una franja `PRESENCIAL`
/// devuelve *"Ese turno solo admite modalidad PRESENCIAL"*, que comparte
/// código HTTP con "turno ya tomado" y pide una reacción distinta.
enum ModalidadFranja {
  presencial('PRESENCIAL'),
  virtual('VIRTUAL'),
  ambas('AMBAS');

  const ModalidadFranja(this.apiValue);

  final String apiValue;

  static ModalidadFranja fromApi(String value) {
    for (final m in ModalidadFranja.values) {
      if (m.apiValue == value) return m;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Modalidad de franja desconocida. Esperadas: '
          '${ModalidadFranja.values.map((m) => m.apiValue).join(', ')}',
    );
  }

  String get etiqueta => switch (this) {
    ModalidadFranja.presencial => 'Presencial',
    ModalidadFranja.virtual => 'Virtual',
    ModalidadFranja.ambas => 'Presencial o virtual',
  };

  /// Qué modalidades de cita admite esta franja.
  ///
  /// La usa la pantalla de reserva para no ofrecer una opción que el backend
  /// va a rechazar. Es más barato no mostrarla que explicar un 409.
  List<ModalidadCita> get admitidas => switch (this) {
    ModalidadFranja.presencial => const [ModalidadCita.presencial],
    ModalidadFranja.virtual => const [ModalidadCita.virtual],
    ModalidadFranja.ambas => const [
      ModalidadCita.presencial,
      ModalidadCita.virtual,
    ],
  };

  bool admite(ModalidadCita modalidad) => admitidas.contains(modalidad);
}
