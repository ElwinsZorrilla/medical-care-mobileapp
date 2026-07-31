import 'package:flutter/material.dart';

import '../core/domain/cita_estado.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../core/widgets/widgets.dart';

/// Galería del sistema de diseño.
///
/// Muestra los 12 componentes, los 5 estados de cita, las dos densidades y
/// los dos temas. Es la herramienta de revisión visual del sistema: si algo
/// se ve mal acá, se ve mal en toda la app.
///
/// **No va a producción.** Vive en `lib/dev/` y ninguna ruta de la app la
/// referencia; se abre desde `GalleryApp` durante el desarrollo.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({
    required this.densidad,
    required this.onCambiarDensidad,
    required this.onCambiarTema,
    super.key,
  });

  final AppDensity densidad;
  final ValueChanged<AppDensity> onCambiarDensidad;
  final VoidCallback onCambiarTema;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppScaffold(
      titulo: 'Sistema',
      acciones: [
        IconButton(
          onPressed: onCambiarTema,
          icon: const Icon(Icons.brightness_6),
          tooltip: 'Cambiar tema',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          _Selector(densidad: densidad, onCambiar: onCambiarDensidad),
          const SizedBox(height: Space.xl),

          const SectionHeader(titulo: 'Riel de estado'),
          const SizedBox(height: Space.md),
          // Los cinco estados en columna: así se lee el argumento del
          // design system — 20 rieles apilados se escanean como una imagen.
          for (final estado in CitaEstado.values) ...[
            StatusRail(
              estado: estado,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dra. Alejandra Peña', style: context.text.heading),
                  const SizedBox(height: Space.xs),
                  Text('Cardiología · Presencial', style: context.text.caption),
                  const SizedBox(height: Space.md),
                  const Row(
                    children: [
                      Expanded(
                        child: DataField(label: 'Fecha', value: '04 AGO'),
                      ),
                      Expanded(
                        child: DataField(label: 'Hora', value: '08:30'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: densidad.separacionLista),
          ],

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Datos clínicos'),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: DataField(label: 'Tipo de sangre', value: 'O+'),
                    ),
                    Expanded(
                      child: DataField(label: 'Presión', value: '120/80'),
                    ),
                  ],
                ),
                SizedBox(height: densidad.paddingTarjeta),
                const DataField(label: 'Exequátur', value: '24-1877'),
                SizedBox(height: densidad.paddingTarjeta),
                const DataField(
                  label: 'Tarifa',
                  value: r'RD$1,500',
                  destacado: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Acciones'),
          const SizedBox(height: Space.md),
          AppButton(label: 'Reservar cita', onPressed: () {}),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Ver disponibilidad',
            variant: AppButtonVariant.secundaria,
            onPressed: () {},
          ),
          const SizedBox(height: Space.sm),
          AppButton(
            label: 'Cancelar cita',
            variant: AppButtonVariant.destructiva,
            onPressed: () {},
          ),
          const SizedBox(height: Space.sm),
          const AppButton(label: 'Deshabilitado', onPressed: null),
          const SizedBox(height: Space.sm),
          AppButton(label: 'Enviando', cargando: true, onPressed: () {}),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Formulario'),
          const SizedBox(height: Space.md),
          const AppTextField(label: 'Correo', hint: 'paciente@correo.com'),
          const SizedBox(height: Space.md),
          const AppTextField(
            label: 'Documento',
            hint: '00112345678',
            monoespaciado: true,
          ),
          const SizedBox(height: Space.md),
          const AppTextField(
            label: 'Contraseña',
            obscure: true,
            error: 'Correo o contraseña incorrectos.',
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Identidad'),
          const SizedBox(height: Space.md),
          const Row(
            children: [
              Avatar(nombre: 'Alejandra Peña'),
              SizedBox(width: Space.md),
              Avatar(nombre: 'Juan Carlos Reyes'),
              SizedBox(width: Space.md),
              Avatar(nombre: 'M'),
            ],
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Carga'),
          const SizedBox(height: Space.md),
          AppCard(child: LoadingSkeleton.lineas(context)),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Sin conexión'),
          const SizedBox(height: Space.md),
          ClipRRect(
            borderRadius: Radii.card,
            child: OfflineBanner(onReintentar: () {}),
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Vacío'),
          const SizedBox(height: Space.md),
          SizedBox(
            height: _altoDemo,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.filete),
                borderRadius: Radii.card,
              ),
              child: EmptyState(
                icono: Icons.event_note,
                titulo: 'Aún no tienes citas',
                detalle: 'Busca un médico para empezar.',
                accion: 'Buscar médico',
                onAccion: () {},
              ),
            ),
          ),

          const SizedBox(height: Space.xl),
          const SectionHeader(titulo: 'Error'),
          const SizedBox(height: Space.md),
          SizedBox(
            height: _altoDemo,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.filete),
                borderRadius: Radii.card,
              ),
              child: ErrorState(
                mensaje: 'Ese turno ya lo tomaron. Elige otra hora.',
                onReintentar: () {},
              ),
            ),
          ),

          const SizedBox(height: Space.huge),
        ],
      ),
    );
  }
}

/// Alto fijo para encuadrar los estados de pantalla completa dentro de la
/// galería. Solo aplica acá: en la app real ocupan la pantalla entera.
const double _altoDemo = 260;

class _Selector extends StatelessWidget {
  const _Selector({required this.densidad, required this.onCambiar});

  final AppDensity densidad;
  final ValueChanged<AppDensity> onCambiar;

  @override
  Widget build(BuildContext context) => SegmentedButton<AppDensity>(
    segments: const [
      ButtonSegment(value: AppDensity.patient, label: Text('Paciente')),
      ButtonSegment(value: AppDensity.clinician, label: Text('Médico')),
    ],
    selected: {densidad},
    onSelectionChanged: (s) => onCambiar(s.first),
  );
}

/// Envoltorio que corre la galería sola, sin el resto de la app.
///
/// Para abrirla:
/// `flutter run -t lib/dev/gallery_main.dart --dart-define=API_BASE_URL=x`
class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  AppDensity _densidad = AppDensity.patient;
  ThemeMode _tema = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MediCare · Sistema',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(density: _densidad),
    darkTheme: AppTheme.dark(density: _densidad),
    themeMode: _tema,
    home: GalleryScreen(
      densidad: _densidad,
      onCambiarDensidad: (d) => setState(() => _densidad = d),
      onCambiarTema: () => setState(
        () =>
            _tema = _tema == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      ),
    ),
  );
}
