import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/chat/data/chat_api.dart';
import 'package:medicare/features/chat/data/chat_dto.dart';
import 'package:medicare/features/chat/data/chat_repository.dart';
import 'package:medicare/features/chat/data/chat_socket.dart';
import 'package:medicare/features/chat/domain/chat.dart';
import 'package:medicare/features/chat/presentation/providers/chat_provider.dart';
import 'package:medicare/features/chat/presentation/screens/abrir_chat_screen.dart';
import 'package:medicare/features/chat/presentation/screens/chat_screen.dart';
import 'package:medicare/features/chat/presentation/screens/conversaciones_screen.dart';

/// Las dos pantallas del chat, ejercidas de punta a punta — RF-31 a RF-34.
///
/// Devuelve tandas **llenas** a proposito: con tres mensajes la lista no
/// desborda la pantalla, no hay scroll, y la paginacion quedaria "probada"
/// llamando al notifier a mano en vez de arrastrando el dedo.
class _ApiFalsa extends ChatApi {
  _ApiFalsa({
    this.totalMensajes = 60,
    this.status,
    this.sinConversaciones = false,
    this.demora = Duration.zero,
  }) : super(Dio());

  final int totalMensajes;
  final bool sinConversaciones;
  final Duration demora;
  int? status;

  int enviados = 0;
  int marcados = 0;
  final List<int?> cursores = [];

  DioException _error(int s) {
    final o = RequestOptions(path: '/chat/conversations');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: s),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<List<ConversacionDto>> conversaciones() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error(status!);
    if (sinConversaciones) return const [];
    return const [
      ConversacionDto(
        idConversacion: 1,
        idPaciente: 7,
        idMedico: 9,
        noLeidos: 3,
        fechaUltimoMensaje: '2026-08-17T12:00:00.000Z',
      ),
      ConversacionDto(idConversacion: 2, idPaciente: 7, idMedico: 11),
    ];
  }

  @override
  Future<ConversacionDto> abrir(int idMedico) async {
    if (status != null) throw _error(status!);
    return const ConversacionDto(idConversacion: 1, idPaciente: 7, idMedico: 9);
  }

  @override
  Future<List<MensajeDto>> mensajes({
    required int idConversacion,
    int? antesDe,
    int limite = 30,
  }) async {
    cursores.add(antesDe);
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error(status!);

    final desde = antesDe == null ? totalMensajes : antesDe - 1;
    final cuantos = desde < limite ? desde : limite;
    return [
      for (var i = 0; i < cuantos; i++)
        MensajeDto(
          idMensaje: desde - i,
          idConversacion: idConversacion,
          // Pares del medico, impares mios: asi las dos burbujas conviven.
          idUsuarioRemitente: (desde - i).isEven ? 9 : 7,
          contenido: 'Mensaje ${desde - i}',
          fechaEnvio: '2026-08-17T12:00:00.000Z',
        ),
    ];
  }

  @override
  Future<MensajeDto> enviar({
    required int idConversacion,
    required String contenido,
    String? urlAdjunto,
  }) async {
    enviados++;
    if (status != null) throw _error(status!);
    return MensajeDto(
      idMensaje: 9000 + enviados,
      idConversacion: idConversacion,
      idUsuarioRemitente: 7,
      contenido: contenido,
      fechaEnvio: '2026-08-17T12:30:00.000Z',
      urlAdjunto: urlAdjunto,
    );
  }

  @override
  Future<void> marcarLeidos(int idConversacion) async {
    marcados++;
    if (status != null) throw _error(status!);
  }
}

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

  void emitir(Mensaje m) => _mensajes.add(m);
}

void main() {
  setUpAll(AppTime.init);

  Widget envolver(Widget hijo, _ApiFalsa api, {_SocketFalso? socket}) =>
      ProviderScope(
        // La misma que usa `main.dart`. Con el default de Riverpod un fallo se
        // queda en `AsyncLoading` ~38 s y el `ErrorState` nunca aparece.
        retry: PoliticaReintento.decidir,
        overrides: [
          chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
          chatSocketProvider.overrideWith((ref) async => socket),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // La pulsacion del skeleton es `repeat(reverse: true)`: mientras uno
          // este montado, `pumpAndSettle` nunca asienta.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: hijo,
        ),
      );

  Future<void> asentar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Con las animaciones apagadas no queda ningun frame agendado, asi que
    // `pumpAndSettle` vuelve con los reintentos todavia pendientes.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<_ApiFalsa> montarLista(
    WidgetTester tester, {
    int? status,
    bool vacia = false,
    Duration demora = Duration.zero,
    bool esperar = true,
  }) async {
    final api = _ApiFalsa(
      status: status,
      sinConversaciones: vacia,
      demora: demora,
    );
    await tester.pumpWidget(envolver(const ConversacionesScreen(), api));
    if (esperar) await asentar(tester);
    return api;
  }

  /// Arrastra hacia lo mas antiguo, como un pulgar repetido.
  ///
  /// Con `reverse: true` el dedo baja para subir en el tiempo. Un solo gesto
  /// no llega al umbral de precarga con una tanda de 30: el usuario tampoco
  /// sube un hilo entero de un tiron.
  Future<void> subirHilo(WidgetTester tester, {int veces = 4}) async {
    for (var i = 0; i < veces; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await asentar(tester);
    }
  }

  Future<_ApiFalsa> montarHilo(
    WidgetTester tester, {
    int? status,
    int totalMensajes = 60,
    Duration demora = Duration.zero,
    _SocketFalso? socket,
    bool esperar = true,
  }) async {
    final api = _ApiFalsa(
      status: status,
      totalMensajes: totalMensajes,
      demora: demora,
    );
    await tester.pumpWidget(
      envolver(
        // 7 es el usuario de la sesion; el router lo inyecta igual.
        const ChatScreen(idConversacion: 1, idUsuario: 7),
        api,
        socket: socket,
      ),
    );
    if (esperar) await asentar(tester);
    return api;
  }

  group('RF-31 — listado de conversaciones', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montarLista(
        tester,
        demora: const Duration(seconds: 5),
        esperar: false,
      );
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('con datos pinta una tarjeta por hilo', (tester) async {
      await montarLista(tester);

      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.text('Conversacion #1'), findsOneWidget);
      // El contador de no leidos, visible sin abrir nada.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('el hilo sin mensajes lo dice, no muestra una fecha vacia', (
      tester,
    ) async {
      await montarLista(tester);

      expect(find.text('Sin mensajes todavia'), findsOneWidget);
    });

    testWidgets('sin conversaciones sale el estado vacio', (tester) async {
      await montarLista(tester, vacia: true);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('el error se muestra y el reintento vuelve a pedir', (
      tester,
    ) async {
      final api = await montarLista(tester, status: 403);
      expect(find.byType(ErrorState), findsOneWidget);

      api.status = null;
      await tester.tap(find.text('Reintentar'));
      await asentar(tester);

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(AppCard), findsNWidgets(2));
    });
  });

  group('RF-31 — el hilo', () {
    testWidgets('pinta los mensajes cargados', (tester) async {
      await montarHilo(tester, totalMensajes: 4);

      expect(find.text('Mensaje 4'), findsOneWidget);
      expect(find.text('Mensaje 1'), findsOneWidget);
    });

    testWidgets('el error del hilo ofrece reintentar', (tester) async {
      final api = await montarHilo(tester, status: 403);
      expect(find.byType(ErrorState), findsOneWidget);

      api.status = null;
      await tester.tap(find.text('Reintentar'));
      await asentar(tester);

      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('un hilo vacio invita a escribir el primero', (tester) async {
      await montarHilo(tester, totalMensajes: 0);

      expect(find.byType(EmptyState), findsOneWidget);
      // El redactor sigue ahi: sin el, un hilo vacio no se podria estrenar.
      expect(find.byType(AppTextField), findsOneWidget);
    });
  });

  group('RF-31 — enviar desde la pantalla', () {
    testWidgets('el texto sale y el campo se limpia', (tester) async {
      final api = await montarHilo(tester, totalMensajes: 4);

      await tester.enterText(find.byType(AppTextField), 'Buenos dias doctor');
      await tester.tap(find.byTooltip('Enviar'));
      await asentar(tester);

      expect(api.enviados, 1);
      expect(find.text('Buenos dias doctor'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('si falla, avisa y no borra lo escrito', (tester) async {
      final api = await montarHilo(tester, totalMensajes: 4);
      api.status = 503;

      await tester.enterText(find.byType(AppTextField), 'Me duele la cabeza');
      await tester.tap(find.byTooltip('Enviar'));
      await asentar(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      // Reescribir un mensaje largo porque se cayo la red es lo que no puede
      // pasar.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Me duele la cabeza',
      );
    });

    testWidgets('el campo vacio no manda nada', (tester) async {
      final api = await montarHilo(tester, totalMensajes: 4);

      await tester.enterText(find.byType(AppTextField), '   ');
      await tester.tap(find.byTooltip('Enviar'));
      await asentar(tester);

      expect(api.enviados, 0);
    });
  });

  group('RF-31 — paginacion con el dedo', () {
    testWidgets('llegar arriba del todo pide la tanda anterior', (
      tester,
    ) async {
      final api = await montarHilo(tester);
      expect(api.cursores, [null]);

      await subirHilo(tester);

      expect(api.cursores.length, greaterThan(1));
      expect(api.cursores[1], 31);
    });

    testWidgets('tras un error de pagina, el pie ofrece el reintento', (
      tester,
    ) async {
      final api = await montarHilo(tester);
      api.status = 403;

      await subirHilo(tester);

      expect(find.text('Cargar anteriores'), findsOneWidget);
      final tras = api.cursores.length;

      // El rebote del scroll no puede volver a pedir; solo el boton.
      await subirHilo(tester, veces: 3);
      expect(api.cursores.length, tras);

      api.status = null;
      await tester.tap(find.text('Cargar anteriores'));
      await asentar(tester);

      expect(find.text('Cargar anteriores'), findsNothing);
      expect(api.cursores.length, tras + 1);
    });
  });

  group('RF-32, RF-33 — lo que llega solo', () {
    testWidgets('abrir la conversacion la marca leida', (tester) async {
      final api = await montarHilo(tester, totalMensajes: 4);

      expect(api.marcados, 1);
    });

    testWidgets('un mensaje del socket aparece sin recargar', (tester) async {
      final socket = _SocketFalso();
      await montarHilo(tester, totalMensajes: 4, socket: socket);
      expect(find.text('Llego mientras leia'), findsNothing);

      socket.emitir(
        Mensaje(
          id: 500,
          idConversacion: 1,
          idRemitente: 9,
          contenido: 'Llego mientras leia',
          enviadoUtc: DateTime.utc(2026, 8, 17, 13),
          leido: false,
        ),
      );
      await asentar(tester);

      expect(find.text('Llego mientras leia'), findsOneWidget);
    });

    testWidgets('el acuse solo se muestra en los mensajes propios', (
      tester,
    ) async {
      await montarHilo(tester, totalMensajes: 2);

      // De dos mensajes, uno es mio (id impar) y otro del medico.
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Leido'), findsNothing);
    });
  });

  group('RF-31 — abrir el chat desde la busqueda', () {
    /// Router minimo: la pantalla puente se reemplaza a si misma, asi que sin
    /// una ruta destino no habria nada que comprobar.
    Future<_ApiFalsa> montarPuente(WidgetTester tester, {int? status}) async {
      final api = _ApiFalsa(status: status, totalMensajes: 4);
      final router = GoRouter(
        initialLocation: '/mensajes/medico/9',
        routes: [
          GoRoute(
            path: '/mensajes/medico/:idMedico',
            builder: (context, state) => AbrirChatScreen(
              idMedico: int.parse(state.pathParameters['idMedico']!),
            ),
          ),
          GoRoute(
            path: '/mensajes/:idConversacion',
            builder: (context, state) => ChatScreen(
              idConversacion: int.parse(
                state.pathParameters['idConversacion']!,
              ),
              idUsuario: 7,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          retry: PoliticaReintento.decidir,
          overrides: [
            chatRepositoryProvider.overrideWithValue(ChatRepository(api)),
            chatSocketProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await asentar(tester);
      return api;
    }

    testWidgets('resuelve el hilo y se quita del medio', (tester) async {
      await montarPuente(tester);

      // Ya no esta la pantalla puente: se reemplazo por el hilo.
      expect(find.byType(AbrirChatScreen), findsNothing);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Mensaje 4'), findsOneWidget);
    });

    testWidgets('si no se puede abrir, lo dice y deja reintentar', (
      tester,
    ) async {
      final api = await montarPuente(tester, status: 503);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);

      api.status = null;
      await tester.tap(find.text('Reintentar'));
      await asentar(tester);

      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });
}
