import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/infra_provider.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/storage/secure_store.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/features/chat/data/chat_api.dart';
import 'package:medicare/features/chat/data/chat_dto.dart';
import 'package:medicare/features/chat/data/chat_repository.dart';
import 'package:medicare/features/chat/data/chat_socket.dart';
import 'package:medicare/features/chat/domain/chat.dart';
import 'package:medicare/features/chat/presentation/providers/chat_provider.dart';

/// Chat — RF-31, RF-32, RF-33, RF-34.
///
/// El envio va por REST y el socket solo avisa. Las pruebas ejercen las dos
/// vias por separado y despues juntas, que es donde aparece el duplicado: el
/// gateway emite `mensaje:nuevo` tambien a quien lo mando.
class _ApiFalsa extends ChatApi {
  _ApiFalsa({this.totalMensajes = 5, this.status}) : super(Dio());

  /// Cuantos mensajes tiene el hilo entero. Con 30 o mas, la primera tanda
  /// vuelve llena y el provider declara que hay pagina anterior.
  final int totalMensajes;

  /// Mutable: hay pruebas que cargan bien y despues rompen el servidor.
  int? status;

  int peticionesMensajes = 0;
  int peticionesConversaciones = 0;
  int? ultimoCursor;
  int? ultimoLimite;
  int marcados = 0;
  int? ultimoAbierto;
  String? ultimoEnviado;

  /// Ids ya usados por `enviar`, para que el mensaje nuevo no choque con los
  /// del historial.
  int _proximoId = 1000;

  DioException _error(int s) {
    final o = RequestOptions(path: '/chat/conversations');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: s),
      type: DioExceptionType.badResponse,
    );
  }

  ConversacionDto _conv(int id, {int noLeidos = 2, String? ultimo}) =>
      ConversacionDto(
        idConversacion: id,
        idPaciente: 7,
        idMedico: 9,
        noLeidos: noLeidos,
        fechaUltimoMensaje: ultimo,
      );

  MensajeDto _msj(int id, {int remitente = 9, bool leido = false}) =>
      MensajeDto(
        idMensaje: id,
        idConversacion: 1,
        idUsuarioRemitente: remitente,
        contenido: 'Mensaje $id',
        fechaEnvio: '2026-08-17T12:00:00.000Z',
        leido: leido,
      );

  @override
  Future<List<ConversacionDto>> conversaciones() async {
    peticionesConversaciones++;
    if (status != null) throw _error(status!);
    return [
      _conv(1, ultimo: '2026-08-17T12:00:00.000Z'),
      // Sin ultimo mensaje: recien abierta.
      _conv(2, noLeidos: 0),
    ];
  }

  @override
  Future<ConversacionDto> abrir(int idMedico) async {
    ultimoAbierto = idMedico;
    if (status != null) throw _error(status!);
    return _conv(1, noLeidos: 0);
  }

  @override
  Future<List<MensajeDto>> mensajes({
    required int idConversacion,
    int? antesDe,
    int limite = 30,
  }) async {
    peticionesMensajes++;
    ultimoCursor = antesDe;
    ultimoLimite = limite;
    if (status != null) throw _error(status!);

    // Ids descendentes desde el cursor: el backend devuelve del mas nuevo al
    // mas viejo.
    final desde = antesDe == null ? totalMensajes : antesDe - 1;
    final cuantos = desde < limite ? desde : limite;
    return [for (var i = 0; i < cuantos; i++) _msj(desde - i)];
  }

  @override
  Future<MensajeDto> enviar({
    required int idConversacion,
    required String contenido,
    String? urlAdjunto,
  }) async {
    ultimoEnviado = contenido;
    if (status != null) throw _error(status!);
    return MensajeDto(
      idMensaje: _proximoId++,
      idConversacion: idConversacion,
      // 7 es el usuario de la sesion en estas pruebas.
      idUsuarioRemitente: 7,
      contenido: contenido,
      fechaEnvio: '2026-08-17T12:05:00.000Z',
      urlAdjunto: urlAdjunto,
    );
  }

  @override
  Future<void> marcarLeidos(int idConversacion) async {
    marcados++;
    if (status != null) throw _error(status!);
  }
}

/// Socket sin red: se le inyectan eventos a mano.
class _SocketFalso extends ChatSocket {
  _SocketFalso() : super(urlBase: 'http://localhost:3000', token: 'jwt');

  final _mensajes = StreamController<Mensaje>.broadcast();
  final _lecturas = StreamController<int>.broadcast();

  @override
  Stream<Mensaje> get mensajes => _mensajes.stream;

  @override
  Stream<int> get lecturas => _lecturas.stream;

  @override
  void conectar() {}

  @override
  Future<void> cerrar() async {
    await _mensajes.close();
    await _lecturas.close();
  }

  /// Emite y cede el turno para que los listeners corran.
  Future<void> emitirMensaje(Mensaje m) async {
    _mensajes.add(m);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> emitirLectura(int idConversacion) async {
    _lecturas.add(idConversacion);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(AppTime.init);

  Mensaje deLaContraparte(int id) => Mensaje(
    id: id,
    idConversacion: 1,
    idRemitente: 9,
    contenido: 'Llego solo $id',
    enviadoUtc: DateTime.utc(2026, 8, 17, 13),
    leido: false,
  );

  ProviderContainer contenedor(_ApiFalsa api, {_SocketFalso? socket}) {
    final c = ProviderContainer(
      retry: PoliticaReintento.decidir,
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
        chatSocketProvider.overrideWith((ref) async => socket),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Carga el hilo 1 y lo deja vivo.
  ///
  /// Sin un oyente, `autoDispose` lo destruye en cuanto el test cede el turno
  /// al event loop — y ahi el socket emitiria al vacio. La pantalla real lo
  /// observa con `ref.watch`, asi que esto reproduce su ciclo de vida, no lo
  /// esquiva.
  Future<void> abrirHilo(ProviderContainer c) async {
    c.listen(hiloProvider(1, 7), (_, _) {});
    await c.read(hiloProvider(1, 7).future);
  }

  group('RF-31 — conversaciones', () {
    test('camino feliz: mapea lo que llega', () async {
      final c = contenedor(_ApiFalsa());
      final hilos = await c.read(conversacionesProvider.future);

      expect(hilos, hasLength(2));
      expect(hilos.first.id, 1);
      expect(hilos.first.idMedico, 9);
      expect(hilos.first.noLeidos, 2);
      expect(hilos.first.tieneSinLeer, isTrue);
      expect(hilos.last.tieneSinLeer, isFalse);
    });

    test('la fecha del ultimo mensaje es UTC — RNF-18', () async {
      final c = contenedor(_ApiFalsa());
      final hilos = await c.read(conversacionesProvider.future);

      expect(hilos.first.ultimoMensajeUtc!.isUtc, isTrue);
      expect(hilos.first.ultimoMensajeUtc, DateTime.utc(2026, 8, 17, 12));
      // Una conversacion recien abierta no tiene instante que mostrar.
      expect(hilos.last.ultimoMensajeUtc, isNull);
    });

    test('camino de error: el servidor rechaza', () async {
      // 403 y no 503: `PoliticaReintento` reintenta los 5xx dos veces.
      final c = contenedor(_ApiFalsa(status: 403));
      await expectLater(
        c.read(conversacionesProvider.future),
        throwsA(isA<Prohibido>()),
      );
    });

    test('abrirCon devuelve el hilo y recarga la lista', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(conversacionesProvider.future);
      expect(api.peticionesConversaciones, 1);

      final conv = await c.read(conversacionesProvider.notifier).abrirCon(9);

      expect(api.ultimoAbierto, 9);
      expect(conv, isNotNull);
      expect(conv!.id, 1);
      // El hilo nuevo tiene que aparecer en la lista sin salir y volver.
      await c.read(conversacionesProvider.future);
      expect(api.peticionesConversaciones, 2);
    });

    test('abrirCon devuelve null si falla, y no recarga', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await c.read(conversacionesProvider.future);

      api.status = 403;
      final conv = await c.read(conversacionesProvider.notifier).abrirCon(9);

      expect(conv, isNull);
      // Recargar tras un fallo dejaria la lista en error por algo que no la
      // afecta: los hilos que ya estaban siguen siendo validos.
      expect(api.peticionesConversaciones, 1);
    });
  });

  group('RF-31 — el hilo', () {
    test('primera tanda: mapea y ordena del mas nuevo al mas viejo', () async {
      final c = contenedor(_ApiFalsa());
      final estado = await c.read(hiloProvider(1, 7).future);

      expect(estado.mensajes, hasLength(5));
      expect(estado.mensajes.first.id, 5);
      expect(estado.mensajes.last.id, 1);
      expect(estado.mensajes.first.enviadoUtc.isUtc, isTrue);
      // Con menos de una tanda llena, no hay nada anterior que pedir.
      expect(estado.hayMasAntiguos, isFalse);
    });

    test('una tanda llena declara que hay pagina anterior', () async {
      final c = contenedor(_ApiFalsa(totalMensajes: 90));
      final estado = await c.read(hiloProvider(1, 7).future);

      expect(estado.mensajes, hasLength(30));
      expect(estado.hayMasAntiguos, isTrue);
    });

    test('esMio decide el lado de la burbuja por id de usuario', () async {
      final c = contenedor(_ApiFalsa());
      final estado = await c.read(hiloProvider(1, 7).future);

      // El historial lo manda el medico (9); el usuario de la sesion es 7.
      expect(estado.mensajes.first.esMio(7), isFalse);
      expect(estado.mensajes.first.esMio(9), isTrue);
    });

    test('403 en el hilo: "esa conversacion no es tuya"', () async {
      final c = contenedor(_ApiFalsa(status: 403));
      await expectLater(
        c.read(hiloProvider(1, 7).future),
        throwsA(
          isA<Prohibido>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('no es tuya'),
          ),
        ),
      );
    });
  });

  group('RF-31 — paginacion por cursor', () {
    test('pide con el id del mensaje mas antiguo que ya tiene', () async {
      final api = _ApiFalsa(totalMensajes: 90);
      final c = contenedor(api);
      await abrirHilo(c);
      expect(api.ultimoCursor, isNull);

      await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();

      // La primera tanda llego con ids 90..61; el cursor es el 61.
      expect(api.ultimoCursor, 61);
      expect(api.ultimoLimite, 30);
      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.mensajes, hasLength(60));
      expect(estado.mensajes.last.id, 31);
    });

    test('no pide nada cuando ya no hay mas antiguos', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();

      expect(api.peticionesMensajes, 1);
    });

    test('un error al paginar no tumba lo que ya se leia', () async {
      final api = _ApiFalsa(totalMensajes: 90);
      final c = contenedor(api);
      await abrirHilo(c);

      api.status = 403;
      await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();

      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.errorAlPaginar, isA<Prohibido>());
      expect(estado.mensajes, hasLength(30));
    });

    test(
      'tras el error deja de pedir: el scroll rebota, no reintenta',
      () async {
        final api = _ApiFalsa(totalMensajes: 90);
        final c = contenedor(api);
        await abrirHilo(c);

        api.status = 503;
        await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();
        final tras = api.peticionesMensajes;

        // El listener del scroll dispara en cada rebote y el usuario que ve el
        // error esta justo al final de la lista.
        for (var i = 0; i < 5; i++) {
          await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();
        }

        expect(api.peticionesMensajes, tras);
      },
    );

    test('reintentarPagina limpia el error y vuelve a pedir', () async {
      final api = _ApiFalsa(totalMensajes: 90);
      final c = contenedor(api);
      await abrirHilo(c);

      api.status = 403;
      await c.read(hiloProvider(1, 7).notifier).cargarAntiguos();
      expect(c.read(hiloProvider(1, 7)).value!.errorAlPaginar, isNotNull);

      api.status = null;
      await c.read(hiloProvider(1, 7).notifier).reintentarPagina();

      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.errorAlPaginar, isNull);
      expect(estado.mensajes, hasLength(60));
    });

    test('reintentarPagina sin error previo no hace nada', () async {
      final api = _ApiFalsa(totalMensajes: 90);
      final c = contenedor(api);
      await abrirHilo(c);

      await c.read(hiloProvider(1, 7).notifier).reintentarPagina();

      expect(api.peticionesMensajes, 1);
    });

    test('el limite se recorta a 100: el backend rechaza mas', () async {
      final api = _ApiFalsa();
      await ChatRepository(api).mensajes(idConversacion: 1, limite: 500);

      expect(api.ultimoLimite, 100);
    });
  });

  group('RF-31 — enviar', () {
    test('el mensaje aparece sin esperar al socket', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      final fallo = await c
          .read(hiloProvider(1, 7).notifier)
          .enviar('Hola doc');

      expect(fallo, isNull);
      expect(api.ultimoEnviado, 'Hola doc');
      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.mensajes.first.contenido, 'Hola doc');
      expect(estado.mensajes.first.esMio(7), isTrue);
    });

    test('se recorta el texto y no se manda lo que quedo vacio', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      final fallo = await c.read(hiloProvider(1, 7).notifier).enviar('   \n  ');

      expect(fallo, isNull);
      expect(api.ultimoEnviado, isNull);
      expect(c.read(hiloProvider(1, 7)).value!.mensajes, hasLength(5));
    });

    test('si el envio falla, el hilo cargado se queda como estaba', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      api.status = 401;
      final fallo = await c.read(hiloProvider(1, 7).notifier).enviar('Hola');

      expect(fallo, isA<NoAutorizado>());
      // Sin esto, un fallo de red borraria el hilo de la pantalla.
      expect(c.read(hiloProvider(1, 7)).value!.mensajes, hasLength(5));
    });
  });

  group('RF-32 — tiempo real', () {
    test('un mensaje que llega por socket entra al hilo', () async {
      final socket = _SocketFalso();
      final c = contenedor(_ApiFalsa(), socket: socket);
      await abrirHilo(c);

      await socket.emitirMensaje(deLaContraparte(77));

      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.mensajes, hasLength(6));
      expect(estado.mensajes.first.id, 77);
    });

    test('el eco del propio envio no lo duplica', () async {
      final socket = _SocketFalso();
      final api = _ApiFalsa();
      final c = contenedor(api, socket: socket);
      await abrirHilo(c);

      await c.read(hiloProvider(1, 7).notifier).enviar('Hola doc');
      final propio = c.read(hiloProvider(1, 7)).value!.mensajes.first;

      // El gateway emite `mensaje:nuevo` tambien a quien lo mando.
      await socket.emitirMensaje(propio);

      final estado = c.read(hiloProvider(1, 7)).value!;
      expect(estado.mensajes.where((m) => m.id == propio.id), hasLength(1));
      expect(estado.mensajes, hasLength(6));
    });

    test('un mensaje de otra conversacion no se cuela', () async {
      final socket = _SocketFalso();
      final c = contenedor(_ApiFalsa(), socket: socket);
      await abrirHilo(c);

      await socket.emitirMensaje(
        Mensaje(
          id: 88,
          idConversacion: 2,
          idRemitente: 9,
          contenido: 'De otro hilo',
          enviadoUtc: DateTime.utc(2026, 8, 17, 13),
          leido: false,
        ),
      );

      expect(c.read(hiloProvider(1, 7)).value!.mensajes, hasLength(5));
    });

    test('sin token no hay socket y el hilo carga igual', () async {
      final c = contenedor(_ApiFalsa());
      final estado = await c.read(hiloProvider(1, 7).future);

      // Sin sesion el gateway rechaza el handshake; el chat degrada a REST en
      // vez de quedarse en blanco.
      expect(estado.mensajes, hasLength(5));
    });
  });

  group('RF-33 — acuses de lectura', () {
    test('entrar a la conversacion la marca leida en el servidor', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      await c.read(hiloProvider(1, 7).notifier).marcarLeidos();

      expect(api.marcados, 1);
    });

    test('el aviso de lectura marca los propios, no los ajenos', () async {
      final socket = _SocketFalso();
      final c = contenedor(_ApiFalsa(), socket: socket);
      await abrirHilo(c);

      // El historial lo manda el medico (9). Se agrega uno mio para tener
      // los dos lados en el hilo: sin el, marcar todo daria el mismo
      // resultado que marcar solo los mios y la prueba no distinguiria.
      await c.read(hiloProvider(1, 7).notifier).enviar('Ya lo vi');
      final antes = c.read(hiloProvider(1, 7)).value!.mensajes;
      expect(antes.where((m) => m.esMio(7)), hasLength(1));
      expect(antes.every((m) => !m.leido), isTrue);

      await socket.emitirLectura(1);

      final despues = c.read(hiloProvider(1, 7)).value!.mensajes;
      expect(despues.where((m) => m.esMio(7)).every((m) => m.leido), isTrue);
      // `leido` en un mensaje recibido significa que lo lei yo, y eso no
      // cambia porque el otro lado abra la conversacion.
      expect(despues.where((m) => !m.esMio(7)).any((m) => m.leido), isFalse);
    });

    test('la lectura de otra conversacion no toca esta', () async {
      final socket = _SocketFalso();
      final c = contenedor(_ApiFalsa(), socket: socket);
      await abrirHilo(c);

      await socket.emitirLectura(2);

      expect(
        c.read(hiloProvider(1, 7)).value!.mensajes.any((m) => m.leido),
        isFalse,
      );
    });

    test('marcarLeidos que falla no rompe la pantalla', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      api.status = 503;
      // No lanza: el acuse es un efecto secundario, no lo que el usuario vino
      // a hacer.
      await c.read(hiloProvider(1, 7).notifier).marcarLeidos();

      expect(c.read(hiloProvider(1, 7)).value!.mensajes, hasLength(5));
    });
  });

  group('RF-34 — adjunto', () {
    test('la url viaja en el envio y vuelve en el mensaje', () async {
      final api = _ApiFalsa();
      final c = contenedor(api);
      await abrirHilo(c);

      // Es una **referencia**: el backend acepta el campo pero no expone
      // ningun endpoint de subida. Ver la declaracion en TRACEABILITY.
      await c
          .read(hiloProvider(1, 7).notifier)
          .enviar('Mira esto', urlAdjunto: '/uploads/analitica.pdf');

      expect(
        c.read(hiloProvider(1, 7)).value!.mensajes.first.urlAdjunto,
        '/uploads/analitica.pdf',
      );
    });
  });

  group('El repositorio traduce', () {
    test('una fecha invalida no revienta la pantalla', () async {
      final api = _FechaRota();
      final r = await ChatRepository(api).conversaciones();

      expect(r.failureONull, isA<ContratoRoto>());
    });
  });

  group('el socket no puede secuestrar al chat', () {
    // Reportado en uso real: el medico abria mensajes y no veia nada, con el
    // backend devolviendo la conversacion y el mensaje sin problema
    // —verificado contra el servidor levantado, no deducido—.
    //
    // La lista y cada hilo **esperan** al socket antes de pedir por REST, y
    // ese orden es el correcto: enganchar el oyente despues de pedir perderia
    // los mensajes que lleguen en el medio. Lo que estaba mal era que ese
    // await no tuviera piso. Las garantias viven en `chatSocket`, asi que es
    // ahi donde se prueban.

    test('devuelve null si el almacen seguro revienta', () async {
      // Pasa en Android cuando el keystore no esta disponible.
      final c = ProviderContainer(
        retry: PoliticaReintento.decidir,
        overrides: [secureStoreProvider.overrideWithValue(_StoreQueRevienta())],
      );
      addTearDown(c.dispose);

      expect(await c.read(chatSocketProvider.future), isNull);
    });

    test('devuelve null si el almacen seguro se cuelga', () async {
      // El modo de fallo peor: no da error, se queda esperando. Sin el
      // timeout, el chat se quedaba en skeleton para siempre.
      final c = ProviderContainer(
        retry: PoliticaReintento.decidir,
        overrides: [secureStoreProvider.overrideWithValue(_StoreColgado())],
      );
      addTearDown(c.dispose);

      expect(
        await c
            .read(chatSocketProvider.future)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw StateError('el provider nunca resolvio'),
            ),
        isNull,
      );
    });

    test('sin token no se abre el socket', () async {
      final c = ProviderContainer(
        retry: PoliticaReintento.decidir,
        overrides: [secureStoreProvider.overrideWithValue(_StoreVacio())],
      );
      addTearDown(c.dispose);

      expect(await c.read(chatSocketProvider.future), isNull);
    });

    test('sin socket, la lista carga igual', () async {
      final c = contenedor(_ApiFalsa());

      expect(await c.read(conversacionesProvider.future), isNotEmpty);
    });

    test('sin socket, el hilo carga igual', () async {
      final c = contenedor(_ApiFalsa());

      expect((await c.read(hiloProvider(1, 7).future)).mensajes, isNotEmpty);
    });
  });
}

/// Almacen que nunca responde. Peor que fallar: no hay error que atrapar.
class _StoreColgado implements SecureStore {
  @override
  Future<String?> leerAccessToken() => Completer<String?>().future;

  @override
  Future<String?> leerRefreshToken() => Completer<String?>().future;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) => Completer<void>().future;

  @override
  Future<void> limpiar() => Completer<void>().future;
}

/// Sin sesion guardada.
class _StoreVacio implements SecureStore {
  @override
  Future<String?> leerAccessToken() async => null;

  @override
  Future<String?> leerRefreshToken() async => null;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> limpiar() async {}
}

/// Almacen seguro inaccesible — pasa en Android cuando el keystore falla.
class _StoreQueRevienta implements SecureStore {
  @override
  Future<String?> leerAccessToken() async => throw StateError('keystore');

  @override
  Future<String?> leerRefreshToken() async => throw StateError('keystore');

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async => throw StateError('keystore');

  @override
  Future<void> limpiar() async => throw StateError('keystore');
}

/// El backend devolviendo algo que no es una fecha.
class _FechaRota extends ChatApi {
  _FechaRota() : super(Dio());

  @override
  Future<List<ConversacionDto>> conversaciones() async => const [
    ConversacionDto(
      idConversacion: 1,
      idPaciente: 7,
      idMedico: 9,
      fechaUltimoMensaje: 'ayer por la tarde',
    ),
  ];
}
