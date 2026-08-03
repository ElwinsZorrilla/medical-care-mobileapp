import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/time/app_time.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/chat.dart';
import '../providers/chat_provider.dart';

/// Una conversacion — RF-31, RF-32, RF-33, RF-34.
///
/// El hilo se pinta **invertido**: el backend devuelve del mas nuevo al mas
/// viejo y `ListView(reverse: true)` los coloca de abajo hacia arriba sin
/// darle la vuelta a la lista en memoria. Ademas arranca ya abajo, que es
/// donde uno espera empezar a leer un chat.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.idConversacion,
    required this.idUsuario,
    super.key,
  });

  final int idConversacion;

  /// Id del usuario de la sesion, inyectado por el router.
  ///
  /// Leerlo aqui de `sesionActualProvider` obligaria a importar de
  /// `features/auth`, y un feature no importa de otro (rubro 3.3). Es con lo
  /// que se decide de que lado va cada burbuja.
  final int idUsuario;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _texto = TextEditingController();
  bool _enviando = false;

  /// Con `reverse: true`, el final de la lista es el mensaje **mas antiguo**.
  static const _umbralPrecarga = 400.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alScrollear);
    // RF-33: entrar a la conversacion es haberla leido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(hiloProvider(widget.idConversacion, widget.idUsuario).notifier)
          .marcarLeidos();
    });
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_alScrollear)
      ..dispose();
    _texto.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (!_scroll.hasClients) return;
    final faltante = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (faltante < _umbralPrecarga) {
      ref
          .read(hiloProvider(widget.idConversacion, widget.idUsuario).notifier)
          .cargarAntiguos();
    }
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() => _enviando = true);
    final fallo = await ref
        .read(hiloProvider(widget.idConversacion, widget.idUsuario).notifier)
        .enviar(texto);

    if (!mounted) return;
    setState(() => _enviando = false);

    if (fallo == null) {
      // Solo se limpia si salio bien: borrar lo escrito tras un fallo de red
      // obligaria a reescribirlo entero.
      _texto.clear();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(fallo.mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final hilo = ref.watch(
      hiloProvider(widget.idConversacion, widget.idUsuario),
    );

    return AppScaffold(
      titulo: 'Conversacion',
      body: Column(
        children: [
          Expanded(
            child: switch (hilo) {
              AsyncLoading<HiloState>() => Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: LoadingSkeleton.lineas(context, cantidad: 8),
              ),
              AsyncError<HiloState>(:final error) => ErrorState(
                mensaje: error is Failure ? error.mensaje : 'Algo salio mal.',
                onReintentar: () => ref.invalidate(
                  hiloProvider(widget.idConversacion, widget.idUsuario),
                ),
              ),
              AsyncData<HiloState>(:final value) =>
                value.mensajes.isEmpty
                    ? const EmptyState(
                        icono: Icons.chat_bubble_outline,
                        titulo: 'Sin mensajes',
                        detalle: 'Escribe el primero abajo.',
                      )
                    : _Hilo(
                        estado: value,
                        idUsuario: widget.idUsuario,
                        scroll: _scroll,
                        onReintentar: () => ref
                            .read(
                              hiloProvider(
                                widget.idConversacion,
                                widget.idUsuario,
                              ).notifier,
                            )
                            .reintentarPagina(),
                      ),
            },
          ),
          _Redactor(
            controlador: _texto,
            enviando: _enviando,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

class _Hilo extends StatelessWidget {
  const _Hilo({
    required this.estado,
    required this.idUsuario,
    required this.scroll,
    required this.onReintentar,
  });

  final HiloState estado;
  final int idUsuario;
  final ScrollController scroll;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final hayPie = estado.hayMasAntiguos || estado.errorAlPaginar != null;

    return ListView.separated(
      controller: scroll,
      // El mas nuevo abajo, como cualquier chat.
      reverse: true,
      padding: const EdgeInsets.all(Space.lg),
      itemCount: estado.mensajes.length + (hayPie ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
      itemBuilder: (context, i) {
        if (i >= estado.mensajes.length) {
          final error = estado.errorAlPaginar;
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                children: [
                  Text(error.mensaje, style: context.text.caption),
                  const SizedBox(height: Space.sm),
                  AppButton(
                    label: 'Cargar anteriores',
                    variant: AppButtonVariant.secundaria,
                    expandido: false,
                    onPressed: onReintentar,
                  ),
                ],
              ),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(Space.md),
            child: Center(child: LoadingSkeleton(height: Space.xl)),
          );
        }
        return _Burbuja(
          mensaje: estado.mensajes[i],
          mio: estado.mensajes[i].esMio(idUsuario),
        );
      },
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.mensaje, required this.mio});

  final Mensaje mensaje;
  final bool mio;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        // Sin tope, un mensaje largo ocuparia el ancho entero y se perderia
        // la senal de quien lo escribio.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: mio ? colors.verde : colors.surface,
            borderRadius: Radii.card,
            border: Border.all(color: colors.filete, width: Strokes.filete),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mensaje.contenido,
                style: text.body.copyWith(
                  color: mio ? colors.surface : colors.ink,
                ),
              ),
              if (mensaje.urlAdjunto case final url?) ...[
                const SizedBox(height: Space.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: Space.md,
                      color: mio ? colors.surface : colors.steel,
                      semanticLabel: 'Adjunto',
                    ),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(
                        url,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption.copyWith(
                          color: mio ? colors.surface : colors.steel,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Space.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppTime.hora(mensaje.enviadoUtc),
                    style: text.caption.copyWith(
                      color: mio ? colors.surface : colors.steel,
                    ),
                  ),
                  // RF-33 — el acuse solo tiene sentido en los propios: saber
                  // si uno mismo leyo no le dice nada a nadie.
                  if (mio) ...[
                    const SizedBox(width: Space.xs),
                    Text(
                      mensaje.leido ? 'Leido' : 'Enviado',
                      style: text.caption.copyWith(color: colors.surface),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Redactor extends StatelessWidget {
  const _Redactor({
    required this.controlador,
    required this.enviando,
    required this.onEnviar,
  });

  final TextEditingController controlador;
  final bool enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: AppTextField(
              label: 'Mensaje',
              controller: controlador,
              maxLines: 4,
              enabled: !enviando,
            ),
          ),
          const SizedBox(width: Space.sm),
          IconButton.filled(
            onPressed: enviando ? null : onEnviar,
            icon: const Icon(Icons.send),
            tooltip: 'Enviar',
          ),
        ],
      ),
    ),
  );
}
