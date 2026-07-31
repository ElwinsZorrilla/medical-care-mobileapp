import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/modalidad.dart';
import '../../../../core/domain/turno.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/cita.dart';
import '../providers/citas_provider.dart';

/// Reservar una cita — RF-18, RF-19, RF-20, RF-21.
///
/// Esta pantalla **no existía** hasta F15. El dominio, el repositorio y sus
/// pruebas estaban desde F08, pero nada los invocaba: `reservar` solo lo
/// llamaban las pruebas y `ReaccionAConflicto` no tenía un solo consumidor.
/// La matriz marcaba RF-19 y RF-20 como cumplidos y un paciente no podía
/// reservar nada. Auditar la matriz contra el código es lo que lo destapó.
class ReservaScreen extends ConsumerStatefulWidget {
  const ReservaScreen({required this.idMedico, super.key});

  final int idMedico;

  @override
  ConsumerState<ReservaScreen> createState() => _ReservaScreenState();
}

class _ReservaScreenState extends ConsumerState<ReservaScreen> {
  Turno? _turno;
  ModalidadCita? _modalidad;
  final _motivo = TextEditingController();
  bool _enviando = false;

  /// Se muestra bajo el selector de modalidad cuando el servidor dice que ese
  /// turno no admite la que se eligió (RF-20, `corregirModalidad`).
  String? _errorModalidad;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// Modalidades que admite el turno elegido.
  ///
  /// Una franja `AMBAS` deja elegir; una `PRESENCIAL` no. Ofrecer las dos
  /// siempre garantizaría un 409 evitable.
  List<ModalidadCita> get _opciones =>
      _turno?.modalidad.admitidas ?? const <ModalidadCita>[];

  Future<void> _confirmar() async {
    final turno = _turno;
    final modalidad = _modalidad;
    if (turno == null || modalidad == null) return;

    setState(() {
      _enviando = true;
      _errorModalidad = null;
    });

    final dia = ref.read(diaReservaProvider);
    final fallo = await ref
        .read(reservaProvider.notifier)
        .reservar(
          SolicitudReserva(
            idMedico: widget.idMedico,
            fecha: AppTime.fechaApi(dia),
            // El string exacto que devolvió el servidor, no uno reconstruido.
            horaInicioApi: turno.inicioApi,
            modalidad: modalidad,
            motivoConsulta: _motivo.text.trim().isEmpty
                ? null
                : _motivo.text.trim(),
          ),
        );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (fallo == null) {
      _avisar('Cita reservada.');
      await Navigator.of(context).maybePop();
      return;
    }

    // RF-20: el 409 está sobrecargado y la reacción se decide en un solo
    // lugar. Nunca se reintenta en silencio.
    switch (ReaccionAConflicto.para(fallo)) {
      case ReaccionAConflicto.refrescarTurnos:
        // Alguien ganó la carrera: la grilla que se está viendo quedó vieja.
        ref.invalidate(turnosDeMedicoProvider(widget.idMedico));
        setState(() {
          _turno = null;
          _modalidad = null;
        });
        _avisar(fallo.mensaje);
      case ReaccionAConflicto.corregirModalidad:
        // Refrescar acá le borraría el turno que eligió sin arreglar nada:
        // lo que falla es la modalidad.
        setState(() => _errorModalidad = fallo.mensaje);
      case ReaccionAConflicto.mostrarMensaje:
        _avisar(fallo.mensaje);
    }
  }

  void _avisar(String mensaje) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(mensaje)));

  @override
  Widget build(BuildContext context) {
    // Al cambiar de dia hay que soltar el turno elegido. Sin esto la grilla se
    // recarga con objetos nuevos, ningun chip aparece marcado, pero
    // `_turno` sigue apuntando al del dia anterior: se mandaria la `fecha`
    // nueva con el `horaInicioApi` viejo, y el contrato exige que concuerden.
    ref.listen(diaReservaProvider, (_, _) {
      setState(() {
        _turno = null;
        _modalidad = null;
        _errorModalidad = null;
      });
    });

    final turnos = ref.watch(turnosDeMedicoProvider(widget.idMedico));
    final dia = ref.watch(diaReservaProvider);

    return AppScaffold(
      titulo: 'Reservar cita',
      body: Column(
        children: [
          _SelectorDia(dia: dia),
          Expanded(
            child: switch (turnos) {
              AsyncLoading<List<Turno>>() => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: LoadingSkeleton.lineas(context, cantidad: 6),
              ),
              AsyncError<List<Turno>>(:final error) => ErrorState(
                mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
                onReintentar: () =>
                    ref.invalidate(turnosDeMedicoProvider(widget.idMedico)),
              ),
              AsyncData<List<Turno>>(:final value) =>
                value.isEmpty
                    ? const EmptyState(
                        icono: Icons.event_busy,
                        titulo: 'No hay turnos ese día',
                        detalle: 'Prueba con otra fecha.',
                      )
                    : _Formulario(
                        turnos: value,
                        seleccionado: _turno,
                        onTurno: (t) => setState(() {
                          _turno = t;
                          // La modalidad depende del turno: al cambiarlo, la
                          // elección anterior puede haber dejado de ser válida.
                          _modalidad = t.modalidad.admitidas.length == 1
                              ? t.modalidad.admitidas.single
                              : null;
                          _errorModalidad = null;
                        }),
                        opciones: _opciones,
                        modalidad: _modalidad,
                        onModalidad: (m) => setState(() {
                          _modalidad = m;
                          _errorModalidad = null;
                        }),
                        errorModalidad: _errorModalidad,
                        motivo: _motivo,
                        puedeConfirmar:
                            _turno != null && _modalidad != null && !_enviando,
                        enviando: _enviando,
                        onConfirmar: _confirmar,
                      ),
            },
          ),
        ],
      ),
    );
  }
}

class _SelectorDia extends ConsumerWidget {
  const _SelectorDia({required this.dia});

  final DateTime dia;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Space.lg,
      vertical: Space.md,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => ref.read(diaReservaProvider.notifier).avanzar(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Día anterior',
        ),
        // `Flexible`: "miercoles, 30 de septiembre de 2026" mide ~310 dp y
        // entre las dos flechas quedan 232 dp en un telefono de 360. Sin esto
        // desborda ya a escala 1.0, y a textScale 2.0 se rompe entero.
        Flexible(
          child: Text(
            // Calendario dominicano, igual que la fecha que se manda (RNF-18).
            AppTime.fechaLarga(dia),
            style: context.text.heading,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          onPressed: () => ref.read(diaReservaProvider.notifier).avanzar(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Día siguiente',
        ),
      ],
    ),
  );
}

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.turnos,
    required this.seleccionado,
    required this.onTurno,
    required this.opciones,
    required this.modalidad,
    required this.onModalidad,
    required this.errorModalidad,
    required this.motivo,
    required this.puedeConfirmar,
    required this.enviando,
    required this.onConfirmar,
  });

  final List<Turno> turnos;
  final Turno? seleccionado;
  final ValueChanged<Turno> onTurno;
  final List<ModalidadCita> opciones;
  final ModalidadCita? modalidad;
  final ValueChanged<ModalidadCita> onModalidad;
  final String? errorModalidad;
  final TextEditingController motivo;
  final bool puedeConfirmar;
  final bool enviando;
  final VoidCallback onConfirmar;

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    // Scroll: con el teclado abierto, el botón de confirmar quedaría fuera
    // de pantalla en un teléfono chico.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(titulo: 'Turnos libres (${turnos.length})'),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final t in turnos)
                _Chip(
                  etiqueta: AppTime.hora(t.inicioUtc),
                  activo: identical(t, seleccionado),
                  onTap: () => onTurno(t),
                ),
            ],
          ),
          if (seleccionado != null) ...[
            const SizedBox(height: Space.xl),
            const SectionHeader(titulo: 'Modalidad'),
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final m in opciones)
                  _Chip(
                    etiqueta: m.etiqueta,
                    activo: m == modalidad,
                    onTap: () => onModalidad(m),
                  ),
              ],
            ),
            if (errorModalidad != null) ...[
              const SizedBox(height: Space.sm),
              Text(
                errorModalidad!,
                style: text.caption.copyWith(color: context.colors.granate),
              ),
            ],
            const SizedBox(height: Space.xl),
            AppTextField(
              label: 'Motivo de consulta (opcional)',
              controller: motivo,
              maxLines: 3,
            ),
            const SizedBox(height: Space.xl),
            AppButton(
              label: enviando ? 'Reservando…' : 'Reservar',
              onPressed: puedeConfirmar ? onConfirmar : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
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
          constraints: const BoxConstraints(
            minHeight: kTactilMinimo,
            minWidth: kTactilMinimo,
          ),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: activo ? colors.verde : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: activo ? colors.verde : colors.filete,
              width: Strokes.filete,
            ),
          ),
          child: Text(
            etiqueta,
            style: context.text.bodyStrong.copyWith(
              color: activo ? colors.surface : colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
