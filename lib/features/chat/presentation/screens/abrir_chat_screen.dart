import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/chat_provider.dart';

/// Puente entre "quiero escribirle a este medico" y su hilo — RF-31.
///
/// Existe para que `busqueda` no tenga que importar el provider de `chat`: un
/// feature no importa de otro (rubro 3.3). La busqueda navega a una ruta y ya;
/// resolver el id de la conversacion es asunto de este feature.
///
/// El backend es idempotente: si ya hay hilo con ese medico, devuelve el
/// mismo. Entrar dos veces no crea dos conversaciones.
class AbrirChatScreen extends ConsumerStatefulWidget {
  const AbrirChatScreen({required this.idMedico, super.key});

  final int idMedico;

  @override
  ConsumerState<AbrirChatScreen> createState() => _AbrirChatScreenState();
}

class _AbrirChatScreenState extends ConsumerState<AbrirChatScreen> {
  bool _fallo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrir());
  }

  Future<void> _abrir() async {
    setState(() => _fallo = false);
    final conversacion = await ref
        .read(conversacionesProvider.notifier)
        .abrirCon(widget.idMedico);

    if (!mounted) return;
    if (conversacion == null) {
      setState(() => _fallo = true);
      return;
    }
    // `pushReplacement`: volver atras desde el hilo debe llevar a la busqueda,
    // no a esta pantalla intermedia que dispararia la apertura otra vez.
    context.pushReplacement(Rutas.chatCon(conversacion.id));
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    titulo: 'Mensajes',
    body: _fallo
        ? ErrorState(
            mensaje: 'No se pudo abrir la conversacion.',
            onReintentar: _abrir,
          )
        : Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: LoadingSkeleton.lineas(context, cantidad: 4),
          ),
  );
}
