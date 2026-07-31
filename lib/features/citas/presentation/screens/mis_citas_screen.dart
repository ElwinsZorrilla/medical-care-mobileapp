import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/cita_estado.dart';
import '../../../../core/domain/medico.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/cita.dart';
import '../providers/citas_provider.dart';

/// Citas del paciente y agenda del médico — RF-23, RF-24.
///
/// Una sola pantalla para los dos roles: el listado es el mismo, cambia la
/// ruta del backend y la densidad. El médico abre esto 20 veces al día, así
/// que su versión va en densidad clínica —más filas por pantalla— sin que
/// haya dos implementaciones que mantener.
class MisCitasScreen extends ConsumerStatefulWidget {
  const MisCitasScreen({this.agenda = false, super.key});

  /// `true` para la agenda del médico.
  final bool agenda;

  @override
  ConsumerState<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends ConsumerState<MisCitasScreen> {
  final _scroll = ScrollController();
  static const _umbralPrecarga = 400.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alScrollear);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_alScrollear)
      ..dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (!_scroll.hasClients) return;
    final faltante = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (faltante < _umbralPrecarga) {
      ref
          .read(listadoCitasProvider(agenda: widget.agenda).notifier)
          .cargarMas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = listadoCitasProvider(agenda: widget.agenda);
    final listado = ref.watch(provider);
    final filtro = ref.watch(filtroEstadoCitaProvider);

    return AppScaffold(
      titulo: widget.agenda ? 'Mi agenda' : 'Mis citas',
      acciones: [
        IconButton(
          onPressed: () => context.go(Rutas.perfil),
          icon: const Icon(Icons.person_outline),
          tooltip: 'Mi perfil',
        ),
      ],
      floatingActionButton: widget.agenda
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Rutas.busqueda),
              icon: const Icon(Icons.search),
              label: const Text('Buscar médico'),
            ),
      body: Column(
        children: [
          const _FiltroEstados(),
          Expanded(
            child: switch (listado) {
              AsyncLoading<CitasState>() => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: LoadingSkeleton.lineas(context, cantidad: 8),
              ),
              AsyncError<CitasState>(:final error) => ErrorState(
                mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
                onReintentar: () => ref.invalidate(provider),
              ),
              AsyncData<CitasState>(:final value) => _Lista(
                estado: value,
                filtro: filtro,
                agenda: widget.agenda,
                scroll: _scroll,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// RF-23 — filtro por estado.
///
/// Es **del lado cliente**: el backend solo acepta paginación. Por eso el
/// contador dice "de las cargadas" y no promete un filtro global — prometerlo
/// sería mentir cuando haya más de una página.
class _FiltroEstados extends ConsumerWidget {
  const _FiltroEstados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seleccionado = ref.watch(filtroEstadoCitaProvider);

    return SizedBox(
      height: Space.huge + Space.md,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        itemCount: CitaEstado.values.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _ChipEstado(
              etiqueta: 'Todas',
              color: context.colors.ink,
              activo: seleccionado == null,
              onTap: () =>
                  ref.read(filtroEstadoCitaProvider.notifier).seleccionar(null),
            );
          }
          final e = CitaEstado.values[i - 1];
          return _ChipEstado(
            etiqueta: e.etiqueta,
            glifo: e.glifo,
            color: e.color(context.brightness),
            activo: seleccionado == e,
            onTap: () =>
                ref.read(filtroEstadoCitaProvider.notifier).seleccionar(e),
          );
        },
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({
    required this.etiqueta,
    required this.color,
    required this.activo,
    required this.onTap,
    this.glifo,
  });

  final String etiqueta;
  final String? glifo;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: activo,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: kTactilMinimo),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: activo ? color.withValues(alpha: 0.12) : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: activo ? color : colors.filete,
              width: Strokes.filete,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glifo != null) ...[
                Text(glifo!, style: context.text.label.copyWith(color: color)),
                const SizedBox(width: Space.xs),
              ],
              Text(
                etiqueta,
                style: context.text.label.copyWith(
                  color: activo ? color : colors.steel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({
    required this.estado,
    required this.filtro,
    required this.agenda,
    required this.scroll,
  });

  final CitasState estado;
  final CitaEstado? filtro;
  final bool agenda;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibles = estado.visibles(filtro);

    if (visibles.isEmpty) {
      return EmptyState(
        icono: Icons.event_note,
        titulo: filtro == null
            ? (agenda ? 'No tienes citas agendadas' : 'Aún no tienes citas')
            : 'Ninguna cita ${filtro!.etiqueta.toLowerCase()}',
        detalle: filtro == null
            ? (agenda
                  ? 'Cuando un paciente reserve, aparecerá acá.'
                  : 'Busca un médico para empezar.')
            : 'Prueba con otro estado o quita el filtro.',
      );
    }

    final density = context.density;
    final hayPie = estado.pagina.hayMas;

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: visibles.length + (hayPie ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: density.separacionLista),
      itemBuilder: (context, i) {
        if (i >= visibles.length) {
          return const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: LoadingSkeleton(height: Space.xl)),
          );
        }
        final cita = visibles[i];
        return _TarjetaCita(
          cita: cita,
          medico: estado.medicos[cita.idMedico],
          agenda: agenda,
        );
      },
    );
  }
}

/// La tarjeta con el riel de estado — el elemento firma del sistema.
class _TarjetaCita extends ConsumerWidget {
  const _TarjetaCita({required this.cita, required this.agenda, this.medico});

  final Cita cita;

  /// `null` mientras el nombre no se resolvió. La tarjeta se pinta igual:
  /// fecha, hora y estado ya son útiles.
  final PerfilMedico? medico;

  final bool agenda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;

    return StatusRail(
      estado: cita.estado,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            agenda
                ? 'Paciente #${cita.idPaciente}'
                : medico?.nombreCompleto ?? 'Médico #${cita.idMedico}',
            style: text.heading,
          ),
          const SizedBox(height: Space.xs),
          Text(
            [
              if (medico != null && !agenda) medico!.especialidadesTexto,
              cita.modalidad.etiqueta,
            ].join(' · '),
            style: text.caption,
          ),
          const SizedBox(height: Space.md),

          // Fecha y hora en versalitas + mono: la cita literal del formulario
          // clínico que define el design system.
          Row(
            children: [
              Expanded(
                child: DataField(
                  label: 'Fecha',
                  value: AppTime.diaMes(cita.inicioUtc),
                ),
              ),
              Expanded(
                child: DataField(
                  label: 'Hora',
                  value: AppTime.hora(cita.inicioUtc),
                ),
              ),
            ],
          ),

          if (cita.motivoConsulta != null &&
              cita.motivoConsulta!.isNotEmpty) ...[
            SizedBox(height: context.density.paddingTarjeta),
            DataField(label: 'Motivo', value: cita.motivoConsulta!),
          ],

          if (cita.esCancelable) ...[
            SizedBox(height: context.density.paddingTarjeta),
            AppButton(
              label: 'Cancelar cita',
              variant: AppButtonVariant.destructiva,
              expandido: false,
              onPressed: () => _cancelar(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  /// RF-22 — cancelación con motivo obligatorio.
  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoMotivo(),
    );
    if (motivo == null || !context.mounted) return;

    final fallo = await ref
        .read(listadoCitasProvider(agenda: agenda).notifier)
        .cancelar(idCita: cita.id, motivo: motivo);

    if (fallo is Failure && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fallo.mensaje)));
    }
  }
}

/// El motivo es obligatorio del lado servidor, así que no se puede confirmar
/// con el campo vacío.
class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo();

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _controller.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'Cuéntanos por qué cancelas.');
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cancelar la cita'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('El médico va a ver el motivo.'),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Motivo',
          controller: _controller,
          error: _error,
          autofocus: true,
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Volver'),
      ),
      // El nombre de la acción no cambia en el camino: el botón de la tarjeta
      // dice "Cancelar cita" y este confirma lo mismo.
      TextButton(onPressed: _confirmar, child: const Text('Cancelar cita')),
    ],
  );
}
