import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/videollamada.dart';
import '../providers/video_provider.dart';

/// La sala de video de una cita — RF-35, RF-36, RF-37.
///
/// **La URL de la sala no se muestra.** Cualquiera que la vea entra a la
/// consulta: un numero de habitacion escrito en la puerta. El boton la abre
/// sin pasarla por la pantalla.
class SalaScreen extends ConsumerStatefulWidget {
  const SalaScreen({required this.idCita, required this.esMedico, super.key});

  final int idCita;

  /// Quien cierra la consulta es el medico. Lo inyecta el router: leerlo aqui
  /// de `sesionActualProvider` obligaria a importar de `features/auth`, y un
  /// feature no importa de otro (rubro 3.3).
  final bool esMedico;

  @override
  ConsumerState<SalaScreen> createState() => _SalaScreenState();
}

class _SalaScreenState extends ConsumerState<SalaScreen> {
  bool _ocupado = false;

  Future<void> _correr(Future<Failure?> Function() accion) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    final fallo = await accion();
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (fallo == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fallo.mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = salaProvider(widget.idCita);
    final sala = ref.watch(provider);

    return AppScaffold(
      titulo: 'Consulta virtual',
      body: switch (sala) {
        AsyncLoading<Videollamada>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 5),
        ),
        AsyncError<Videollamada>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salio mal.',
          onReintentar: () => ref.invalidate(provider),
        ),
        AsyncData<Videollamada>(:final value) => _Detalle(
          sala: value,
          esMedico: widget.esMedico,
          ocupado: _ocupado,
          onEntrar: () => _correr(ref.read(provider.notifier).entrar),
          onCambiar: (e) =>
              _correr(() => ref.read(provider.notifier).cambiarEstado(e)),
        ),
      },
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({
    required this.sala,
    required this.esMedico,
    required this.ocupado,
    required this.onEntrar,
    required this.onCambiar,
  });

  final Videollamada sala;
  final bool esMedico;
  final bool ocupado;
  final VoidCallback onEntrar;
  final void Function(EstadoVideollamada) onCambiar;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final duracion = sala.duracion;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Cita #${sala.idCita}', style: text.heading),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Expanded(
                      child: DataField(
                        label: 'Estado',
                        value: sala.estado.etiqueta,
                      ),
                    ),
                    Expanded(
                      child: DataField(
                        label: 'Proveedor',
                        value: sala.proveedor,
                      ),
                    ),
                  ],
                ),
                if (sala.inicioRealUtc case final inicio?) ...[
                  SizedBox(height: context.density.paddingTarjeta),
                  DataField(label: 'Comenzo', value: AppTime.fechaHora(inicio)),
                ],
                if (duracion != null) ...[
                  SizedBox(height: context.density.paddingTarjeta),
                  DataField(
                    label: 'Duracion',
                    value: '${duracion.inMinutes} min',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.lg),

          if (sala.estado.admiteEntrada) ...[
            AppButton(
              label: 'Entrar a la consulta',
              onPressed: ocupado ? null : onEntrar,
            ),
            const SizedBox(height: Space.sm),
            Text(
              // Se explica por que no hay un enlace que copiar: sin esto,
              // "no aparece el link" se lee como un error de la app.
              'La sala se abre en el navegador o en la app de Jitsi. El enlace '
              'no se muestra porque cualquiera que lo tenga entra a tu '
              'consulta.',
              style: text.caption,
            ),
          ] else
            EmptyState(
              icono: sala.estado == EstadoVideollamada.finalizada
                  ? Icons.check_circle_outline
                  : Icons.videocam_off_outlined,
              titulo: sala.estado == EstadoVideollamada.finalizada
                  ? 'La consulta termino'
                  : 'La consulta no pudo realizarse',
              detalle: 'Ya no se puede entrar a esta sala.',
            ),

          // RF-37 — cerrar la consulta es del medico. El paciente que sale de
          // la llamada no puede darla por terminada para los dos.
          if (esMedico && !sala.estado.esTerminal) ...[
            const SizedBox(height: Space.lg),
            if (sala.estado.puedeIrA(EstadoVideollamada.finalizada))
              AppButton(
                label: 'Finalizar consulta',
                variant: AppButtonVariant.secundaria,
                onPressed: ocupado
                    ? null
                    : () => onCambiar(EstadoVideollamada.finalizada),
              ),
            const SizedBox(height: Space.sm),
            AppButton(
              label: 'Marcar como fallida',
              variant: AppButtonVariant.destructiva,
              onPressed: ocupado
                  ? null
                  : () => onCambiar(EstadoVideollamada.fallida),
            ),
          ],
        ],
      ),
    );
  }
}
