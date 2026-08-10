import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/medico.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/admin_provider.dart';

/// Cola de verificación de exequátur — RF-11, lado admin.
///
/// El registro/edición de perfil médico deja `estadoVerificacion` en
/// `PENDIENTE` y no hay forma de moverlo desde la app: esta pantalla es la
/// que le falta al rol ADMIN para poder hacerlo.
class VerificacionScreen extends ConsumerStatefulWidget {
  const VerificacionScreen({super.key});

  @override
  ConsumerState<VerificacionScreen> createState() => _VerificacionScreenState();
}

class _VerificacionScreenState extends ConsumerState<VerificacionScreen> {
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
      ref.read(colaVerificacionProvider.notifier).cargarMas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cola = ref.watch(colaVerificacionProvider);

    return AppScaffold(
      titulo: 'Verificación de médicos',
      acciones: [
        IconButton(
          onPressed: () => context.push(Rutas.perfil),
          icon: const Icon(Icons.person_outline),
          tooltip: 'Mi perfil',
        ),
      ],
      body: switch (cola) {
        AsyncLoading<ColaVerificacionState>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 8),
        ),
        AsyncError<ColaVerificacionState>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salió mal.',
          onReintentar: () => ref.invalidate(colaVerificacionProvider),
        ),
        AsyncData<ColaVerificacionState>(:final value) =>
          value.pagina.estaVacia
              ? const EmptyState(
                  icono: Icons.task_alt,
                  titulo: 'No hay médicos pendientes',
                  detalle: 'Todos los exequátures están al día.',
                )
              : _ListaPendientes(estado: value, scroll: _scroll),
      },
    );
  }
}

class _ListaPendientes extends ConsumerWidget {
  const _ListaPendientes({required this.estado, required this.scroll});

  final ColaVerificacionState estado;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final density = context.density;
    final pagina = estado.pagina;
    final hayPie = pagina.hayMas || estado.errorAlPaginar != null;

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: pagina.items.length + (hayPie ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: density.separacionLista),
      itemBuilder: (context, i) {
        if (i >= pagina.items.length) {
          final error = estado.errorAlPaginar;
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                children: [
                  Text(error.mensaje, style: context.text.caption),
                  const SizedBox(height: Space.md),
                  AppButton(
                    label: 'Cargar más',
                    variant: AppButtonVariant.secundaria,
                    expandido: false,
                    onPressed: () => ref
                        .read(colaVerificacionProvider.notifier)
                        .reintentarPagina(),
                  ),
                ],
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(Space.lg),
            child: Center(child: LoadingSkeleton(height: Space.xl)),
          );
        }
        return _TarjetaPendiente(medico: pagina.items[i]);
      },
    );
  }
}

class _TarjetaPendiente extends ConsumerStatefulWidget {
  const _TarjetaPendiente({required this.medico});

  final PerfilMedico medico;

  @override
  ConsumerState<_TarjetaPendiente> createState() => _TarjetaPendienteState();
}

class _TarjetaPendienteState extends ConsumerState<_TarjetaPendiente> {
  bool _procesando = false;

  Future<void> _resolver(
    Future<Result<PerfilMedico>> Function(int) accion,
    String etiquetaExito,
  ) async {
    setState(() => _procesando = true);
    final resultado = await accion(widget.medico.idMedico);
    if (!mounted) return;
    setState(() => _procesando = false);

    final mensajero = ScaffoldMessenger.of(context);
    resultado.when(
      ok: (_) => mensajero.showSnackBar(
        SnackBar(
          content: Text('${widget.medico.nombreCompleto} $etiquetaExito.'),
        ),
      ),
      fallo: (failure) =>
          mensajero.showSnackBar(SnackBar(content: Text(failure.mensaje))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final medico = widget.medico;
    final notificador = ref.read(colaVerificacionProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Avatar(nombre: medico.nombreCompleto),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(medico.nombreCompleto, style: text.heading),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Exequátur ${medico.numExequatur}',
                      style: text.caption,
                    ),
                    if (medico.especialidades.isNotEmpty) ...[
                      const SizedBox(height: Space.xs),
                      Text(
                        medico.especialidadesTexto,
                        style: text.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Rechazar',
                  variant: AppButtonVariant.destructiva,
                  cargando: _procesando,
                  onPressed: _procesando
                      ? null
                      : () => _resolver(notificador.rechazar, 'rechazado'),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: AppButton(
                  label: 'Verificar',
                  cargando: _procesando,
                  onPressed: _procesando
                      ? null
                      : () => _resolver(notificador.verificar, 'verificado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
