import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/chat.dart';
import '../providers/chat_provider.dart';

/// Listado de conversaciones — RF-31, RF-33.
class ConversacionesScreen extends ConsumerWidget {
  const ConversacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hilos = ref.watch(conversacionesProvider);

    return AppScaffold(
      titulo: 'Mensajes',
      body: switch (hilos) {
        AsyncLoading<List<Conversacion>>() => Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: LoadingSkeleton.lineas(context, cantidad: 6),
        ),
        AsyncError<List<Conversacion>>(:final error) => ErrorState(
          mensaje: error is Failure ? error.mensaje : 'Algo salio mal.',
          onReintentar: () => ref.invalidate(conversacionesProvider),
        ),
        AsyncData<List<Conversacion>>(:final value) =>
          value.isEmpty
              ? const EmptyState(
                  icono: Icons.forum_outlined,
                  titulo: 'Todavia no tienes mensajes',
                  detalle:
                      'Puedes escribirle a un medico desde su ficha en la '
                      'busqueda.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(Space.lg),
                  itemCount: value.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(height: context.density.separacionLista),
                  itemBuilder: (context, i) => _Fila(conversacion: value[i]),
                ),
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.conversacion});

  final Conversacion conversacion;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final ultimo = conversacion.ultimoMensajeUtc;

    return AppCard(
      onTap: () => context.push(Rutas.chatCon(conversacion.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conversacion #${conversacion.id}',
                  // Con mensajes sin leer va en negrita: el peso es el
                  // segundo canal, para que no dependa solo del contador.
                  style: conversacion.tieneSinLeer
                      ? text.bodyStrong
                      : text.body,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  ultimo == null
                      ? 'Sin mensajes todavia'
                      : AppTime.fechaHora(ultimo),
                  style: text.caption,
                ),
              ],
            ),
          ),
          if (conversacion.tieneSinLeer) ...[
            const SizedBox(width: Space.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              constraints: const BoxConstraints(minWidth: Space.lg),
              decoration: BoxDecoration(
                color: colors.granate,
                borderRadius: Radii.chip,
              ),
              child: Text(
                '${conversacion.noLeidos}',
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: colors.surface),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
