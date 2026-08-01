import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/notificacion.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/notificaciones_provider.dart';

/// Bandeja de notificaciones — RF-28, RF-29, RF-30.
///
/// **Bandeja in-app, no push.** El backend guarda y sirve las notificaciones,
/// pero no hay proveedor de push configurado (BACKEND_ISSUES.md #5). Prometer
/// una alerta que nunca llega es peor que no prometerla: aqui se ven al abrir
/// la app, y el badge dice cuantas hay sin leer.
class BandejaScreen extends ConsumerStatefulWidget {
  const BandejaScreen({super.key});

  @override
  ConsumerState<BandejaScreen> createState() => _BandejaScreenState();
}

class _BandejaScreenState extends ConsumerState<BandejaScreen> {
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
      ref.read(bandejaProvider.notifier).cargarMas();
    }
  }

  Future<void> _marcarTodas() async {
    final fallo = await ref.read(bandejaProvider.notifier).marcarTodasLeidas();
    if (!mounted || fallo == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fallo.mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final bandeja = ref.watch(bandejaProvider);

    return AppScaffold(
      titulo: 'Notificaciones',
      acciones: [
        if (bandeja.value?.sinLeer case final n? when n > 0)
          TextButton(
            onPressed: _marcarTodas,
            child: const Text('Marcar todas'),
          ),
      ],
      body: switch (bandeja) {
        AsyncLoading<BandejaState>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 8),
        ),
        AsyncError<BandejaState>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salio mal.',
          onReintentar: () => ref.invalidate(bandejaProvider),
        ),
        AsyncData<BandejaState>(:final value) =>
          value.pagina.estaVacia
              ? const EmptyState(
                  icono: Icons.notifications_none,
                  titulo: 'No tienes notificaciones',
                  detalle:
                      'Te avisamos aqui cuando confirmen o cancelen una cita.',
                )
              : _Lista(estado: value, scroll: _scroll),
      },
    );
  }
}

class _Lista extends ConsumerWidget {
  const _Lista({required this.estado, required this.scroll});

  final BandejaState estado;
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
                    label: 'Cargar mas',
                    variant: AppButtonVariant.secundaria,
                    expandido: false,
                    onPressed: () =>
                        ref.read(bandejaProvider.notifier).reintentarPagina(),
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
        return _Tarjeta(notificacion: pagina.items[i]);
      },
    );
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({required this.notificacion});

  final Notificacion notificacion;

  /// Un glifo por tipo. El estado nunca se comunica solo por color: una
  /// cancelacion y una confirmacion tienen que distinguirse sin verlo.
  IconData get _icono => switch (notificacion.tipo) {
    TipoNotificacion.recordatorio => Icons.alarm,
    TipoNotificacion.confirmacion => Icons.check_circle_outline,
    TipoNotificacion.cancelacion => Icons.cancel_outlined,
    TipoNotificacion.mensaje => Icons.chat_bubble_outline,
    TipoNotificacion.sistema => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;
    final leida = notificacion.leida;

    return AppCard(
      onTap: leida
          ? null
          : () =>
                ref.read(bandejaProvider.notifier).marcarLeida(notificacion.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _icono,
            color: leida ? colors.steel : colors.verde,
            semanticLabel: notificacion.tipo.name,
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notificacion.titulo,
                  // Sin leer va en negrita: el peso es el segundo canal, para
                  // que no dependa solo del color del icono.
                  style: leida ? text.body : text.bodyStrong,
                ),
                const SizedBox(height: Space.xs),
                Text(notificacion.cuerpo, style: text.caption),
              ],
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            notificacion.antiguedadDesde(AppTime.ahoraUtc()),
            style: text.caption,
          ),
        ],
      ),
    );
  }
}
