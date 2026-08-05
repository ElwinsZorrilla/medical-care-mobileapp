import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/config/env.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/infra_provider.dart';
import '../../../../core/network/result.dart';
import '../../data/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../data/chat_socket.dart';
import '../../domain/chat.dart';

part 'chat_provider.g.dart';

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) =>
    ChatRepository(ChatApi(ref.watch(dioClienteProvider)));

/// Socket de tiempo real — RF-32.
///
/// `keepAlive`: la conexion sobrevive a salir de una conversacion. Abrirla y
/// cerrarla en cada pantalla haria un handshake por cada toque y perderia los
/// mensajes que llegan mientras se navega.
///
/// Se cierra cuando el provider se destruye, que es al cerrar sesion.
///
/// **Ni falla ni se cuelga: devuelve `null` si no se pudo abrir.**
///
/// La lista de conversaciones y cada hilo lo esperan antes de pedir por REST,
/// para que un mensaje que llegue durante la carga no se pierda entre que se
/// pide y se engancha el oyente. Ese orden es correcto, pero deja al chat
/// entero colgando de este provider: si quedara en error o sin resolver, el
/// usuario no veria un solo mensaje **teniendo el REST sano al lado**.
///
/// Fue el modo de fallo reportado en uso real —el medico abria mensajes y no
/// habia nada—, con el backend devolviendo la conversacion y el mensaje sin
/// problema. Por eso las dos garantias van aca y no en cada consumidor:
///
/// - **No lanza.** Cualquier excepcion se traduce en `null`.
/// - **Termina.** El keystore de Android puede quedarse esperando sin error;
///   3 s es de sobra para leer una clave local y no se nota al abrir.
///
/// Sin socket el chat sigue andando por REST. Lo unico que se pierde es que
/// los mensajes lleguen solos, y eso lo cubre volver a entrar.
@Riverpod(keepAlive: true)
Future<ChatSocket?> chatSocket(Ref ref) async {
  try {
    final token = await ref
        .watch(secureStoreProvider)
        .leerAccessToken()
        .timeout(const Duration(seconds: 3));
    // Sin sesion no hay socket: el gateway rechaza el handshake sin token y
    // reintentaria en bucle.
    if (token == null || token.isEmpty) return null;

    final socket = ChatSocket(urlBase: _origen(Env.apiBaseUrl), token: token)
      ..conectar();
    ref.onDispose(socket.cerrar);
    return socket;
  } on Object {
    return null;
  }
}

/// Quita el sufijo `/api`: el namespace del socket cuelga de la raiz del
/// servidor, no del prefijo REST.
String _origen(String apiBaseUrl) {
  final sinBarra = apiBaseUrl.endsWith('/')
      ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
      : apiBaseUrl;
  return sinBarra.endsWith('/api')
      ? sinBarra.substring(0, sinBarra.length - 4)
      : sinBarra;
}

/// Hilos del usuario — RF-31.
@riverpod
class Conversaciones extends _$Conversaciones {
  @override
  Future<List<Conversacion>> build() async {
    // Un mensaje nuevo cambia el contador de no leidos de su hilo: sin esto,
    // la lista se quedaria con el numero viejo hasta salir y volver.
    //
    // Se engancha **antes** de pedir: un mensaje que llegue mientras carga la
    // lista se perderia si el oyente se atara despues. Esperar aca es seguro
    // porque `chatSocket` no lanza ni se cuelga — ver su documentacion.
    final socket = await ref.watch(chatSocketProvider.future);
    if (socket != null) {
      final sub = socket.mensajes.listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
    }
    return _pedir();
  }

  /// RF-31 — abre (o recupera) la conversacion con un medico.
  ///
  /// Devuelve la conversacion, o `null` si fallo. Es idempotente del lado
  /// servidor: tocar dos veces no crea dos hilos.
  Future<Conversacion?> abrirCon(int idMedico) async {
    final r = await ref.read(chatRepositoryProvider).abrir(idMedico);
    if (r.esOk) ref.invalidateSelf();
    return r.valorONull;
  }

  Future<List<Conversacion>> _pedir() async {
    final r = await ref.read(chatRepositoryProvider).conversaciones();
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}

/// Lo cargado de un hilo, mas el error de la tanda anterior si lo hubo.
class HiloState {
  const HiloState({
    required this.mensajes,
    required this.hayMasAntiguos,
    this.errorAlPaginar,
  });

  /// Del **mas nuevo al mas viejo**, como los devuelve el backend.
  final List<Mensaje> mensajes;
  final bool hayMasAntiguos;
  final Failure? errorAlPaginar;

  HiloState copiar({
    List<Mensaje>? mensajes,
    bool? hayMasAntiguos,
    Failure? errorAlPaginar,
  }) => HiloState(
    mensajes: mensajes ?? this.mensajes,
    hayMasAntiguos: hayMasAntiguos ?? this.hayMasAntiguos,
    errorAlPaginar: errorAlPaginar ?? this.errorAlPaginar,
  );

  HiloState sinError({List<Mensaje>? mensajes, bool? hayMasAntiguos}) =>
      HiloState(
        mensajes: mensajes ?? this.mensajes,
        hayMasAntiguos: hayMasAntiguos ?? this.hayMasAntiguos,
      );
}

/// Mensajes de una conversacion — RF-31, RF-32, RF-33.
///
/// Recibe el `idUsuario` de la sesion como parte de la familia. No lo lee de
/// `sesionActualProvider` porque eso obligaria a `chat` a importar de `auth`,
/// y un feature no importa de otro (rubro 3.3). Lo necesita para RF-33: sin
/// saber cuales mensajes son propios, un acuse de lectura ajeno terminaria
/// marcando tambien los recibidos.
@riverpod
class Hilo extends _$Hilo {
  static const _tanda = 30;
  bool _cargandoMas = false;

  @override
  Future<HiloState> build(int idConversacion, int idUsuario) async {
    // RF-32 — lo que llega sin pedirlo. Igual que en `Conversaciones`: se
    // engancha antes de pedir, y esperar es seguro porque `chatSocket` no
    // lanza ni se cuelga.
    final socket = await ref.watch(chatSocketProvider.future);
    if (socket != null) {
      final nuevos = socket.mensajes
          .where((m) => m.idConversacion == idConversacion)
          .listen(_recibir);
      final leidos = socket.lecturas
          .where((id) => id == idConversacion)
          .listen((_) => _marcarMiosLeidos());
      ref
        ..onDispose(nuevos.cancel)
        ..onDispose(leidos.cancel);
    }

    final mensajes = await _pedir();
    return HiloState(
      mensajes: mensajes,
      hayMasAntiguos: mensajes.length == _tanda,
    );
  }

  /// Inserta un mensaje que llego por socket.
  ///
  /// Se descarta si ya esta: el propio envio agrega el mensaje al confirmarse
  /// por REST, y el socket lo emite tambien a quien lo mando. Sin este filtro
  /// el remitente lo veria dos veces.
  void _recibir(Mensaje m) {
    final actual = state.value;
    if (actual == null) return;
    if (actual.mensajes.any((x) => x.id == m.id)) return;
    state = AsyncData(actual.copiar(mensajes: [m, ...actual.mensajes]));
  }

  /// RF-33 — la contraparte leyo.
  ///
  /// Se marcan **solo los propios**. `leido` en un mensaje recibido significa
  /// que lo lei yo, y eso no cambia porque el otro lado abra la conversacion.
  /// Marcarlos todos se veria igual en pantalla —el acuse solo se pinta en
  /// los propios— y dejaria el modelo mintiendo para el primero que decida
  /// mostrarlo del otro lado.
  void _marcarMiosLeidos() {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(
      actual.copiar(
        mensajes: [
          for (final m in actual.mensajes)
            if (m.esMio(idUsuario) && !m.leido)
              Mensaje(
                id: m.id,
                idConversacion: m.idConversacion,
                idRemitente: m.idRemitente,
                contenido: m.contenido,
                urlAdjunto: m.urlAdjunto,
                enviadoUtc: m.enviadoUtc,
                leido: true,
              )
            else
              m,
        ],
      ),
    );
  }

  /// Carga la tanda anterior. Pagina por **cursor**: en un hilo que crece
  /// mientras se lee, el offset repetiria o saltaria mensajes.
  Future<void> cargarAntiguos() async {
    final actual = state.value;
    if (actual == null ||
        !actual.hayMasAntiguos ||
        _cargandoMas ||
        actual.errorAlPaginar != null ||
        actual.mensajes.isEmpty) {
      return;
    }

    _cargandoMas = true;
    try {
      final antiguos = await _pedir(antesDe: actual.mensajes.last.id);
      state = AsyncData(
        HiloState(
          mensajes: [...actual.mensajes, ...antiguos],
          hayMasAntiguos: antiguos.length == _tanda,
        ),
      );
    } on Failure catch (e) {
      state = AsyncData(actual.copiar(errorAlPaginar: e));
    } finally {
      _cargandoMas = false;
    }
  }

  Future<void> reintentarPagina() async {
    final actual = state.value;
    if (actual?.errorAlPaginar == null) return;
    state = AsyncData(actual!.sinError());
    await cargarAntiguos();
  }

  /// RF-31 — enviar.
  ///
  /// Va por REST y no por socket: un mensaje escrito con la conexion caida se
  /// perderia sin codigo de estado ni reintento. Al confirmarse se agrega al
  /// hilo sin esperar al socket, que puede tardar o no llegar.
  Future<Failure?> enviar(String contenido, {String? urlAdjunto}) async {
    final texto = contenido.trim();
    if (texto.isEmpty) return null;

    final r = await ref
        .read(chatRepositoryProvider)
        .enviar(
          idConversacion: idConversacion,
          contenido: texto,
          urlAdjunto: urlAdjunto,
        );

    if (r case Ok(:final valor)) {
      _recibir(valor);
      ref.invalidate(conversacionesProvider);
      return null;
    }
    return r.failureONull;
  }

  /// RF-33 — marcar leidos los de la contraparte.
  Future<void> marcarLeidos() async {
    final r = await ref
        .read(chatRepositoryProvider)
        .marcarLeidos(idConversacion);
    if (r.esOk) ref.invalidate(conversacionesProvider);
  }

  Future<List<Mensaje>> _pedir({int? antesDe}) async {
    final r = await ref
        .read(chatRepositoryProvider)
        .mensajes(
          idConversacion: idConversacion,
          antesDe: antesDe,
          limite: _tanda,
        );
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}
