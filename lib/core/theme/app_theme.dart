import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Paleta ya resuelta para el brillo activo.
///
/// Los widgets leen `context.colors.ink` y nunca deciden entre claro y
/// oscuro. El modo oscuro se deriva de los mismos tokens, no es una paleta
/// aparte.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.ink,
    required this.steel,
    required this.paper,
    required this.surface,
    required this.verde,
    required this.ambar,
    required this.granate,
    required this.cielo,
    required this.filete,
  });

  factory AppPalette.of(Brightness brightness) => brightness == Brightness.dark
      ? const AppPalette(
          ink: AppColors.inkDark,
          steel: AppColors.steelDark,
          paper: AppColors.paperDark,
          surface: AppColors.surfaceDark,
          verde: AppColors.verdeDark,
          ambar: AppColors.ambarDark,
          granate: AppColors.granateDark,
          cielo: AppColors.cieloDark,
          filete: AppColors.fileteDark,
        )
      : const AppPalette(
          ink: AppColors.ink,
          steel: AppColors.steel,
          paper: AppColors.paper,
          surface: AppColors.surface,
          verde: AppColors.verde,
          ambar: AppColors.ambar,
          granate: AppColors.granate,
          cielo: AppColors.cielo,
          filete: AppColors.filete,
        );

  final Color ink;
  final Color steel;
  final Color paper;
  final Color surface;
  final Color verde;
  final Color ambar;
  final Color granate;
  final Color cielo;
  final Color filete;

  @override
  AppPalette copyWith({
    Color? ink,
    Color? steel,
    Color? paper,
    Color? surface,
    Color? verde,
    Color? ambar,
    Color? granate,
    Color? cielo,
    Color? filete,
  }) => AppPalette(
    ink: ink ?? this.ink,
    steel: steel ?? this.steel,
    paper: paper ?? this.paper,
    surface: surface ?? this.surface,
    verde: verde ?? this.verde,
    ambar: ambar ?? this.ambar,
    granate: granate ?? this.granate,
    cielo: cielo ?? this.cielo,
    filete: filete ?? this.filete,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      ink: Color.lerp(ink, other.ink, t)!,
      steel: Color.lerp(steel, other.steel, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      verde: Color.lerp(verde, other.verde, t)!,
      ambar: Color.lerp(ambar, other.ambar, t)!,
      granate: Color.lerp(granate, other.granate, t)!,
      cielo: Color.lerp(cielo, other.cielo, t)!,
      filete: Color.lerp(filete, other.filete, t)!,
    );
  }
}

/// Escala tipográfica — DESIGN_SYSTEM.md §4.
///
/// Tres cortes, tres trabajos. En esta app **los números son el contenido**:
/// `120/80`, `08:30`, `500mg c/8h`, exequátur `24-1877`. Por eso los datos
/// clínicos van en monoespaciada tabular — se alinean en columna y se leen
/// como lectura de instrumento, no como prosa.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  const AppTextStyles({
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.label,
    required this.data,
    required this.dataLg,
  });

  /// Construye la escala para una densidad y un color de texto.
  ///
  /// El cuerpo baja de 15 a 14 en densidad clínica; el resto de la escala se
  /// mantiene para que la jerarquía no se aplaste.
  factory AppTextStyles.build({
    required AppDensity density,
    required Color ink,
    required Color steel,
  }) {
    final base = density.tamanoBase;
    return AppTextStyles(
      display: GoogleFonts.archivo(
        fontSize: 32,
        height: 36 / 32,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      title: GoogleFonts.archivo(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      heading: GoogleFonts.publicSans(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      body: GoogleFonts.publicSans(
        fontSize: base,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyStrong: GoogleFonts.publicSans(
        fontSize: base,
        height: 22 / 15,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      caption: GoogleFonts.publicSans(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: steel,
      ),
      // Versalitas con tracking abierto: la cita directa del formulario
      // clínico. Aparece encima de cada dato: TIPO DE SANGRE / O+
      label: GoogleFonts.publicSans(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: steel,
      ),
      data: GoogleFonts.ibmPlexMono(
        fontSize: base,
        height: 20 / 15,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      dataLg: GoogleFonts.ibmPlexMono(
        fontSize: 24,
        height: 28 / 24,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    );
  }

  final TextStyle display;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle label;
  final TextStyle data;
  final TextStyle dataLg;

  @override
  AppTextStyles copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? caption,
    TextStyle? label,
    TextStyle? data,
    TextStyle? dataLg,
  }) => AppTextStyles(
    display: display ?? this.display,
    title: title ?? this.title,
    heading: heading ?? this.heading,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    caption: caption ?? this.caption,
    label: label ?? this.label,
    data: data ?? this.data,
    dataLg: dataLg ?? this.dataLg,
  );

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) return this;
    return AppTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      heading: TextStyle.lerp(heading, other.heading, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      data: TextStyle.lerp(data, other.data, t)!,
      dataLg: TextStyle.lerp(dataLg, other.dataLg, t)!,
    );
  }
}

/// Densidad activa, inyectada por el rol del usuario.
@immutable
class AppDensityTheme extends ThemeExtension<AppDensityTheme> {
  const AppDensityTheme(this.density);

  final AppDensity density;

  @override
  AppDensityTheme copyWith({AppDensity? density}) =>
      AppDensityTheme(density ?? this.density);

  /// La densidad no interpola: se salta al valor destino a mitad de camino.
  /// Un padding a medias entre dos densidades no significa nada.
  @override
  AppDensityTheme lerp(ThemeExtension<AppDensityTheme>? other, double t) {
    if (other is! AppDensityTheme) return this;
    return t < 0.5 ? this : other;
  }
}

/// Construcción del tema.
abstract final class AppTheme {
  static ThemeData light({AppDensity density = AppDensity.patient}) =>
      _build(Brightness.light, density);

  static ThemeData dark({AppDensity density = AppDensity.patient}) =>
      _build(Brightness.dark, density);

  static ThemeData _build(Brightness brightness, AppDensity density) {
    final palette = AppPalette.of(brightness);
    final text = AppTextStyles.build(
      density: density,
      ink: palette.ink,
      steel: palette.steel,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.verde,
      brightness: brightness,
      primary: palette.verde,
      onPrimary: brightness == Brightness.dark
          ? AppColors.paperDark
          : AppColors.surface,
      error: palette.granate,
      surface: palette.surface,
      onSurface: palette.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.paper,
      // La jerarquía se construye con filetes de 1px, no con sombras.
      // Un filete dice "esto es un límite"; una sombra difusa no dice nada.
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: palette.filete, width: Strokes.filete),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.filete,
        thickness: Strokes.filete,
        space: Strokes.filete,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.paper,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.title,
      ),
      // Misma transición en las dos plataformas: el spec M3 actualizado la
      // define como fundido con desplazamiento corto, que es exactamente el
      // "180ms easeOutCubic, nada de hero elaborado" del design system.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      extensions: [palette, text, AppDensityTheme(density)],
    );
  }
}

/// Accesos cortos. Un widget escribe `context.colors.verde`, nunca
/// `AppColors.verde` directo — así el modo oscuro sale gratis.
extension AppThemeContext on BuildContext {
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;

  AppTextStyles get text => Theme.of(this).extension<AppTextStyles>()!;

  AppDensity get density =>
      Theme.of(this).extension<AppDensityTheme>()!.density;

  Brightness get brightness => Theme.of(this).brightness;
}
