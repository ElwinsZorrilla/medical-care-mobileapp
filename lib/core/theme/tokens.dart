// Tokens del sistema de diseño. Ver docs/DESIGN_SYSTEM.md.
//
// Nada de esto se redefine en un widget. Si un color, un espacio o un radio
// hace falta y no está acá, se agrega acá — no se escribe literal en la
// pantalla. El gate rechaza un `Color(0xFF...)` dentro de un widget.

import 'package:flutter/material.dart';

/// Seis valores con trabajo asignado. Ninguno decora.
abstract final class AppColors {
  /// Texto primario y filetes estructurales.
  static const ink = Color(0xFF0D1F2D);

  /// Texto secundario, metadatos, etiquetas.
  static const steel = Color(0xFF5C7284);

  /// Fondo. Blanco frío de panel, no crema.
  static const paper = Color(0xFFF2F5F7);

  /// Tarjetas y superficies elevadas.
  static const surface = Color(0xFFFFFFFF);

  /// Acción primaria · estado confirmado. 5.8:1 contra blanco.
  static const verde = Color(0xFF0E7C66);

  /// Estado pendiente · atención.
  static const ambar = Color(0xFFB26B00);

  /// Cancelado · no asistió · destructivo. **Solo** para eso.
  static const granate = Color(0xFFB3261E);

  /// Enlaces · info · modalidad virtual.
  static const cielo = Color(0xFF2D6CA2);

  // ── Modo oscuro: derivado de los mismos valores, no una paleta aparte ──
  static const inkDark = Color(0xFFE8EDF1);
  static const steelDark = Color(0xFF9DB0BF);
  static const paperDark = Color(0xFF0B141B);
  static const surfaceDark = Color(0xFF14212B);
  static const verdeDark = Color(0xFF4DB89E);
  static const ambarDark = Color(0xFFE0A040);
  static const granateDark = Color(0xFFE9776E);
  static const cieloDark = Color(0xFF6FA8D8);

  /// La jerarquía se construye con filetes, no con sombras.
  static const filete = Color(0x1F0D1F2D); // ink @ 12%
  static const fileteDark = Color(0x1FE8EDF1);
}

/// Base 4pt.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
  static const huge = 64.0;
}

/// Radio deliberadamente corto: un expediente tiene esquinas.
abstract final class Radii {
  static const sm = 4.0; // chips, campos
  static const md = 8.0; // tarjetas
  static const lg = 12.0; // hojas modales

  static const chip = BorderRadius.all(Radius.circular(sm));
  static const card = BorderRadius.all(Radius.circular(md));
  static const sheet = BorderRadius.vertical(top: Radius.circular(lg));
}

/// Grosores de filete. El riel de estado es el elemento firma.
abstract final class Strokes {
  static const filete = 1.0;
  static const riel = 4.0;
  static const foco = 2.0;
}

/// Movimiento: poco y con motivo.
///
/// Todo pasa por [Motion.of], que devuelve 0ms si el usuario pidió menos
/// movimiento. Una animación que no consulta esto es un hallazgo del gate.
abstract final class Motion {
  static const riel = Duration(milliseconds: 240);
  static const lista = Duration(milliseconds: 200);
  static const listaOffset = Duration(milliseconds: 30);
  static const pagina = Duration(milliseconds: 180);
  static const presion = Duration(milliseconds: 90);

  /// Pulso del skeleton de carga. Más lento que el resto a propósito: no
  /// compite por atención, solo dice "acá va a haber algo".
  static const skeleton = Duration(milliseconds: 900);

  static const curvaRiel = Curves.easeOutCubic;
  static const curvaLista = Curves.easeOut;
  static const curvaPagina = Curves.easeOutCubic;
  static const curvaPresion = Curves.easeOut;

  /// Escala de la presión de botón.
  static const escalaPresion = 0.98;

  /// Cuántos elementos de lista entran escalonados antes de aparecer secos.
  static const escalonMaximo = 6;

  /// Duración efectiva según las preferencias de accesibilidad del sistema.
  ///
  /// `MediaQuery.disableAnimations` se respeta sin excepciones: si está
  /// activo, todo cae a cero.
  static Duration of(BuildContext context, Duration duracion) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duracion;
}

/// Las dos densidades del sistema.
///
/// No son dos sistemas de diseño: son los mismos tokens con otra escala de
/// espaciado. El paciente abre la app 3–4 veces al mes y necesita aire; el
/// médico la abre 20 veces al día y necesita ver más filas sin scrollear.
enum AppDensity {
  /// Paciente: aire, pasos claros.
  patient(
    paddingTarjeta: Space.lg,
    separacionLista: Space.md,
    altoFila: 72.0,
    tamanoBase: 15.0,
  ),

  /// Médico: densidad. Un layout aireado le cuesta scroll y tiempo real.
  clinician(
    paddingTarjeta: Space.md,
    separacionLista: Space.xs,
    altoFila: 56.0,
    tamanoBase: 14.0,
  );

  const AppDensity({
    required this.paddingTarjeta,
    required this.separacionLista,
    required this.altoFila,
    required this.tamanoBase,
  });

  final double paddingTarjeta;
  final double separacionLista;
  final double altoFila;
  final double tamanoBase;
}

/// Objetivo táctil mínimo. No negociable, no se anuncia.
const double kTactilMinimo = 48.0;
