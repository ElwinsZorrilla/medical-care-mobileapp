import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/modalidad.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/disponibilidad.dart';
import '../providers/agenda_provider.dart';

/// Franjas de disponibilidad del médico — RF-16, RF-17.
class DisponibilidadScreen extends ConsumerWidget {
  const DisponibilidadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final franjas = ref.watch(misFranjasProvider);

    return AppScaffold(
      titulo: 'Mi disponibilidad',
      tituloCompacto: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Agregar franja'),
      ),
      body: switch (franjas) {
        AsyncLoading<List<Disponibilidad>>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 6),
        ),
        AsyncError<List<Disponibilidad>>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
          onReintentar: () => ref.invalidate(misFranjasProvider),
        ),
        AsyncData<List<Disponibilidad>>(:final value) =>
          value.isEmpty
              ? const EmptyState(
                  icono: Icons.event_available,
                  titulo: 'Aún no defines tu horario',
                  detalle:
                      'Sin franjas, los pacientes no ven turnos para reservar '
                      'contigo.',
                )
              : _ListaPorDia(franjas: value),
      },
    );
  }

  Future<void> _abrirFormulario(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        builder: (_) => const _FormularioFranja(),
      );
}

/// Agrupa por día, en el orden del backend (domingo primero).
class _ListaPorDia extends ConsumerWidget {
  const _ListaPorDia({required this.franjas});

  final List<Disponibilidad> franjas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activas = franjas.where((f) => f.activo).toList();
    final dias = DiaSemana.values
        .where((d) => activas.any((f) => f.dia == d))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(Space.lg),
      itemCount: dias.length,
      itemBuilder: (context, i) {
        final dia = dias[i];
        final delDia = activas.where((f) => f.dia == dia).toList()
          ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));

        return Padding(
          padding: const EdgeInsets.only(bottom: Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(titulo: dia.etiqueta),
              const SizedBox(height: Space.md),
              for (final f in delDia) ...[
                _TarjetaFranja(franja: f),
                SizedBox(height: context.density.separacionLista),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TarjetaFranja extends ConsumerWidget {
  const _TarjetaFranja({required this.franja});

  final Disponibilidad franja;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.text;

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Las horas son datos: monoespaciada tabular.
                Text(franja.rango, style: text.data),
                const SizedBox(height: Space.xs),
                Text(
                  '${franja.modalidad.etiqueta} · '
                  'turnos de ${franja.duracionSlotMin} min · '
                  '${franja.turnosPorDia} por día',
                  style: text.caption,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _confirmarDesactivar(context, ref),
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: 'Desactivar franja',
          ),
        ],
      ),
    );
  }

  /// RF-17.
  ///
  /// Se confirma porque el backend **no ofrece reactivar**: desactivar es de
  /// una sola dirección, y un toque accidental obligaría a crear la franja de
  /// nuevo.
  Future<void> _confirmarDesactivar(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Desactivar esta franja'),
        content: Text(
          'Dejarás de recibir reservas los ${franja.dia.etiqueta.toLowerCase()} '
          'de ${franja.rango}. No se puede reactivar: tendrías que crearla de '
          'nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !context.mounted) return;

    final fallo = await ref
        .read(misFranjasProvider.notifier)
        .desactivar(franja.id);

    if (fallo is Failure && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fallo.mensaje)));
    }
  }
}

/// RF-16 — alta de franja.
class _FormularioFranja extends ConsumerStatefulWidget {
  const _FormularioFranja();

  @override
  ConsumerState<_FormularioFranja> createState() => _FormularioFranjaState();
}

class _FormularioFranjaState extends ConsumerState<_FormularioFranja> {
  DiaSemana _dia = DiaSemana.lunes;
  HoraDelDia _inicio = const HoraDelDia(8, 0);
  HoraDelDia _fin = const HoraDelDia(12, 0);
  int _duracion = 30;
  ModalidadFranja _modalidad = ModalidadFranja.presencial;

  bool _guardando = false;
  String? _error;

  /// Duraciones que tienen sentido en consulta. Un campo libre invitaría a
  /// escribir 7 minutos.
  static const _duraciones = [15, 20, 30, 45, 60];

  /// Cuántos turnos saldrían con lo elegido.
  int get _turnos {
    final disponible = _fin.enMinutos - _inicio.enMinutos;
    return disponible <= 0 ? 0 : disponible ~/ _duracion;
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    // El backend responde 409 —no 400— si la hora fin no es mayor. Se
    // comprueba antes para no gastar el viaje ni confundir el mensaje.
    if (_fin <= _inicio) {
      setState(
        () => _error = 'La hora de fin debe ser mayor que la de inicio.',
      );
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final fallo = await ref
        .read(misFranjasProvider.notifier)
        .crear(
          dia: _dia,
          horaInicio: _inicio,
          horaFin: _fin,
          duracionSlotMin: _duracion,
          modalidad: _modalidad,
        );

    if (!mounted) return;

    if (fallo is Failure) {
      setState(() {
        _guardando = false;
        _error = fallo.mensaje;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    // Scrollable a propósito: con el teclado abierto, en una pantalla chica o
    // con `textScale` ampliado, el formulario no cabe y el botón de guardar
    // queda fuera de vista. Una prueba de widget lo detectó desbordando 22px.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: Space.lg,
        right: Space.lg,
        top: Space.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nueva franja', style: text.title),
          const SizedBox(height: Space.xl),

          Text('DÍA', style: text.label),
          const SizedBox(height: Space.sm),
          SizedBox(
            height: kTactilMinimo,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DiaSemana.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (context, i) {
                final d = DiaSemana.values[i];
                return _ChipDia(
                  dia: d,
                  activo: d == _dia,
                  onTap: () => setState(() => _dia = d),
                );
              },
            ),
          ),
          const SizedBox(height: Space.lg),

          Row(
            children: [
              Expanded(
                child: _SelectorHora(
                  label: 'Desde',
                  valor: _inicio,
                  onCambiar: (h) => setState(() => _inicio = h),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _SelectorHora(
                  label: 'Hasta',
                  valor: _fin,
                  onCambiar: (h) => setState(() => _fin = h),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),

          Text('DURACIÓN DEL TURNO', style: text.label),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final d in _duraciones)
                ChoiceChip(
                  label: Text('$d min'),
                  selected: d == _duracion,
                  onSelected: (_) => setState(() => _duracion = d),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),

          Text('MODALIDAD', style: text.label),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final m in ModalidadFranja.values)
                ChoiceChip(
                  label: Text(m.etiqueta),
                  selected: m == _modalidad,
                  onSelected: (_) => setState(() => _modalidad = m),
                ),
            ],
          ),

          const SizedBox(height: Space.lg),
          // Retroalimentación inmediata: el médico ve el efecto antes de
          // guardar, en vez de descubrirlo cuando un paciente no encuentra
          // turnos.
          Text(
            _turnos == 0
                ? 'Con estas horas no cabe ningún turno.'
                : 'Genera $_turnos turnos cada ${_dia.etiqueta.toLowerCase()}.',
            style: text.caption,
          ),

          if (_error != null) ...[
            const SizedBox(height: Space.md),
            Text(
              _error!,
              style: text.body.copyWith(color: context.colors.granate),
            ),
          ],

          const SizedBox(height: Space.xl),
          AppButton(
            label: 'Guardar franja',
            cargando: _guardando,
            onPressed: _guardar,
          ),
          const SizedBox(height: Space.md),
        ],
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({
    required this.dia,
    required this.activo,
    required this.onTap,
  });

  final DiaSemana dia;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: activo,
      label: dia.etiqueta,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(
            minWidth: kTactilMinimo,
            minHeight: kTactilMinimo,
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: activo ? colors.verde : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: activo ? colors.verde : colors.filete,
              width: Strokes.filete,
            ),
          ),
          child: ExcludeSemantics(
            child: Text(
              dia.abreviatura,
              style: context.text.label.copyWith(
                color: activo ? colors.surface : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorHora extends StatelessWidget {
  const _SelectorHora({
    required this.label,
    required this.valor,
    required this.onCambiar,
  });

  final String label;
  final HoraDelDia valor;
  final ValueChanged<HoraDelDia> onCambiar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: context.text.label),
        const SizedBox(height: Space.xs),
        InkWell(
          onTap: () async {
            final elegida = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: valor.hora, minute: valor.minuto),
            );
            if (elegida != null) {
              onCambiar(HoraDelDia(elegida.hour, elegida.minute));
            }
          },
          borderRadius: Radii.chip,
          child: Container(
            alignment: Alignment.centerLeft,
            constraints: const BoxConstraints(minHeight: kTactilMinimo),
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            decoration: BoxDecoration(
              borderRadius: Radii.chip,
              border: Border.all(color: colors.filete, width: Strokes.filete),
            ),
            child: Text(valor.toApi(), style: context.text.data),
          ),
        ),
      ],
    );
  }
}
