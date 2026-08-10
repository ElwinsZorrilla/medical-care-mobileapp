import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/medico_directorio.dart';
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
  const ConversacionesScreen({required this.esMedico, super.key});

  /// Qué rol mira la lista, inyectado por el router.
  ///
  /// Decide **quién es el otro** en cada hilo: el paciente ve al médico, y el
  /// médico vería al paciente. Leerlo aquí de `sesionActualProvider` obligaría
  /// a importar de `features/auth` (rubro 3.3).
  final bool esMedico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hilos = ref.watch(conversacionesProvider);

    return AppScaffold(
      titulo: 'Mensajes',
      body: Column(
        children: [
          // Acceso rapido desde una cita activa: el paciente no deberia
          // tener que pasar por la busqueda para escribirle al medico con
          // el que ya tiene turno.
          if (!esMedico) const _AccesoRapidoCitaActiva(),
          Expanded(
            child: switch (hilos) {
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
                            'Puedes escribirle a un medico desde su ficha en '
                            'la busqueda.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(Space.lg),
                        itemCount: value.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(height: context.density.separacionLista),
                        itemBuilder: (context, i) =>
                            _Fila(conversacion: value[i], esMedico: esMedico),
                      ),
            },
          ),
        ],
      ),
    );
  }
}

/// Chips horizontales con los medicos de citas PENDIENTE/CONFIRMADA.
///
/// No filtra contra las conversaciones ya abiertas: tocar un medico con el
/// que ya hay hilo simplemente lo reabre — `POST /chat/conversations` es
/// idempotente. Si no hay ninguna cita activa, no ocupa espacio.
class _AccesoRapidoCitaActiva extends ConsumerWidget {
  const _AccesoRapidoCitaActiva();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicos = ref.watch(medicosConCitaActivaProvider);

    return switch (medicos) {
      AsyncData<List<int>>(:final value) when value.isNotEmpty => Padding(
        padding: const EdgeInsets.only(top: Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              child: Text('Citas activas', style: context.text.caption),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: Space.huge,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (context, i) => _ChipMedico(idMedico: value[i]),
              ),
            ),
          ],
        ),
      ),
      // Cargando, sin citas activas, o fallo: no bloquea la lista de
      // conversaciones. Es un atajo, no la pantalla principal.
      _ => const SizedBox.shrink(),
    };
  }
}

class _ChipMedico extends ConsumerWidget {
  const _ChipMedico({required this.idMedico});

  final int idMedico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.text;

    return FutureBuilder(
      future: ref.watch(medicoDirectorioProvider).resolver(idMedico),
      builder: (context, snapshot) {
        final nombre = snapshot.data?.nombreCompleto ?? 'Médico #$idMedico';
        return Semantics(
          button: true,
          label: 'Escribirle a $nombre',
          child: InkWell(
            onTap: () => context.push(Rutas.abrirChatCon(idMedico)),
            borderRadius: Radii.chip,
            child: Container(
              alignment: Alignment.center,
              constraints: const BoxConstraints(minHeight: kTactilMinimo),
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: Radii.chip,
                border: Border.all(color: colors.filete, width: Strokes.filete),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: Space.md,
                    color: colors.verde,
                  ),
                  const SizedBox(width: Space.xs),
                  Text(nombre, style: text.bodyStrong),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Con quién es el hilo.
///
/// **La respuesta solo trae ids.** `ConversacionResponseDto` devuelve
/// `idPaciente` e `idMedico` y ningún nombre, así que hay que resolverlo
/// aparte — igual que las citas, y por eso se reusa `MedicoDirectorio`, que ya
/// cachea y coalesce las peticiones repetidas.
///
/// **Y solo se puede resolver una de las dos direcciones.** El paciente ve el
/// nombre del médico porque existe `GET /doctors/{id}`. El médico **no** puede
/// ver el del paciente: la única ruta de `patients` es `/me`
/// ([#10](../../../../../docs/BACKEND_ISSUES.md)). Ahí se muestra el id con su
/// etiqueta en vez de inventar un nombre o dejar un número suelto.
class _Titulo extends ConsumerWidget {
  const _Titulo({
    required this.conversacion,
    required this.esMedico,
    required this.estilo,
  });

  final Conversacion conversacion;
  final bool esMedico;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (esMedico) {
      return Text('Paciente #${conversacion.idPaciente}', style: estilo);
    }

    return FutureBuilder(
      future: ref
          .watch(medicoDirectorioProvider)
          .resolver(conversacion.idMedico),
      builder: (context, snapshot) => Text(
        // Mientras resuelve —o si el médico ya no está— se muestra el id: un
        // texto vacío haría que la fila salte cuando llegue el nombre.
        snapshot.data?.nombreCompleto ?? 'Médico #${conversacion.idMedico}',
        style: estilo,
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.conversacion, required this.esMedico});

  final Conversacion conversacion;
  final bool esMedico;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                _Titulo(
                  conversacion: conversacion,
                  esMedico: esMedico,
                  // Con mensajes sin leer va en negrita: el peso es el
                  // segundo canal, para que no dependa solo del contador.
                  estilo: conversacion.tieneSinLeer
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
