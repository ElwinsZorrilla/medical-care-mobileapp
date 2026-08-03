import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/notificaciones_api.dart';
import 'package:medicare/core/data/notificaciones_dto.dart';
import 'package:medicare/core/data/notificaciones_provider.dart';
import 'package:medicare/core/data/notificaciones_repository.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/notificaciones/presentation/screens/bandeja_screen.dart';

/// La bandeja vista desde la pantalla — RF-28, RF-29, RF-30.
///
/// Quedaba declarada en la revision de F10 con 1 de 87 lineas cubiertas: el
/// notifier estaba probado y la pantalla que lo usa, no. Un `itemCount` mal
/// puesto o un boton conectado al metodo equivocado no habrian salido.
///
/// Devuelve paginas **llenas** a proposito: con dos notificaciones la lista
/// no desborda la pantalla, no hay scroll, y RF-29 quedaria "probado"
/// llamando al notifier a mano.
class _ApiFalsa extends NotificacionesApi {
  _ApiFalsa({
    this.total = 25,
    this.status,
    this.demora = Duration.zero,
    this.todasLeidas = false,
  }) : super(Dio());

  final int total;
  final bool todasLeidas;
  final Duration demora;
  int? status;

  /// Se rompe solo la pagina 2: el error de paginacion no puede tumbar lo que
  /// ya se estaba leyendo.
  bool fallaPagina2 = false;

  int marcarTodas = 0;
  int? ultimaMarcada;
  final List<int> paginasPedidas = [];

  DioException _error(int s) {
    final o = RequestOptions(path: '/notifications/me');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: s),
      type: DioExceptionType.badResponse,
    );
  }

  NotificacionDto _dto(int i, {bool? leida}) => NotificacionDto(
    idNotificacion: i,
    tipo: i.isEven ? 'CONFIRMACION' : 'CANCELACION',
    titulo: 'Aviso $i',
    cuerpo: 'Cuerpo del aviso $i.',
    leida: leida ?? todasLeidas,
    fechaEnvio: '2026-08-17T12:00:00.000Z',
    idCita: 5,
  );

  @override
  Future<PaginaNotificacionesDto> bandeja({
    int pagina = 1,
    int limite = 10,
  }) async {
    paginasPedidas.add(pagina);
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error(status!);
    if (fallaPagina2 && pagina == 2) throw _error(500);

    final desde = (pagina - 1) * limite;
    final restantes = total - desde;
    final cuantas = restantes < limite ? restantes : limite;
    return PaginaNotificacionesDto(
      data: [for (var i = 0; i < cuantas; i++) _dto(desde + i)],
      total: total,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<int> sinLeer() async {
    if (status != null) throw _error(status!);
    return todasLeidas ? 0 : 3;
  }

  @override
  Future<NotificacionDto> marcarLeida(int id) async {
    ultimaMarcada = id;
    if (status != null) throw _error(status!);
    return _dto(id, leida: true);
  }

  @override
  Future<void> marcarTodasLeidas() async {
    marcarTodas++;
    if (status != null) throw _error(status!);
  }
}

void main() {
  setUpAll(AppTime.init);

  Future<void> asentar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Con las animaciones apagadas no queda ningun frame agendado, asi que
    // `pumpAndSettle` vuelve con los reintentos todavia pendientes.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    int total = 25,
    int? status,
    bool todasLeidas = false,
    Duration demora = Duration.zero,
    bool esperar = true,
  }) async {
    final api = _ApiFalsa(
      total: total,
      status: status,
      todasLeidas: todasLeidas,
      demora: demora,
    );
    await tester.pumpWidget(
      ProviderScope(
        // La misma que usa `main.dart`. Con el default de Riverpod un fallo se
        // queda en `AsyncLoading` ~38 s y el `ErrorState` nunca aparece.
        retry: PoliticaReintento.decidir,
        overrides: [
          notificacionesRepositoryProvider.overrideWithValue(
            NotificacionesRepository(api),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const BandejaScreen(),
        ),
      ),
    );
    if (esperar) await asentar(tester);
    return api;
  }

  group('los cuatro estados', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montar(tester, demora: const Duration(seconds: 5), esperar: false);
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('con datos pinta una tarjeta por aviso', (tester) async {
      await montar(tester, total: 3);

      expect(find.text('Aviso 0'), findsOneWidget);
      expect(find.text('Cuerpo del aviso 0.'), findsOneWidget);
      expect(find.byType(AppCard), findsNWidgets(3));
    });

    testWidgets('sin notificaciones sale el estado vacio', (tester) async {
      await montar(tester, total: 0);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('el error se muestra y el reintento vuelve a pedir', (
      tester,
    ) async {
      final api = await montar(tester, status: 403);
      expect(find.byType(ErrorState), findsOneWidget);

      api.status = null;
      await tester.tap(find.text('Reintentar'));
      await asentar(tester);

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(AppCard), findsWidgets);
    });
  });

  group('RF-30 — marcar leidas', () {
    testWidgets('tocar una la marca', (tester) async {
      final api = await montar(tester, total: 3);

      await tester.tap(find.text('Aviso 1'));
      await asentar(tester);

      expect(api.ultimaMarcada, 1);
    });

    testWidgets('una ya leida no se vuelve a marcar', (tester) async {
      final api = await montar(tester, total: 3, todasLeidas: true);

      await tester.tap(find.text('Aviso 1'));
      await asentar(tester);

      // Sin esta guarda, cada toque en la lista seria una peticion inutil.
      expect(api.ultimaMarcada, isNull);
    });

    testWidgets('"Marcar todas" aparece cuando hay sin leer', (tester) async {
      await montar(tester, total: 3);

      expect(find.text('Marcar todas'), findsOneWidget);
    });

    testWidgets('"Marcar todas" desaparece cuando no queda ninguna', (
      tester,
    ) async {
      // En un test aparte y no como segundo `montar`: `ProviderScope` reusa
      // su elemento entre `pumpWidget`s del mismo tipo, asi que el estado del
      // primer montaje sobreviviria y la asercion pasaria por inercia.
      await montar(tester, total: 3, todasLeidas: true);

      expect(find.text('Marcar todas'), findsNothing);
    });

    testWidgets('"Marcar todas" llama al metodo de todas', (tester) async {
      final api = await montar(tester, total: 3);

      await tester.tap(find.text('Marcar todas'));
      await asentar(tester);

      // Conectado al metodo correcto: marcar una por una seria N peticiones.
      expect(api.marcarTodas, 1);
      expect(api.ultimaMarcada, isNull);
    });

    testWidgets('si falla, avisa en vez de quedarse callada', (tester) async {
      final api = await montar(tester, total: 3);
      api.status = 403;

      await tester.tap(find.text('Marcar todas'));
      await asentar(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('RF-29 — paginacion con el dedo', () {
    testWidgets('llegar al final pide la pagina siguiente', (tester) async {
      final api = await montar(tester);
      expect(api.paginasPedidas, [1]);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await asentar(tester);

      expect(api.paginasPedidas, contains(2));
    });

    testWidgets('tras un error de pagina, el pie ofrece el reintento', (
      tester,
    ) async {
      final api = await montar(tester);
      api.fallaPagina2 = true;

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await asentar(tester);

      expect(find.text('Cargar mas'), findsOneWidget);
      final tras = api.paginasPedidas.length;

      // El rebote del scroll no puede volver a pedir; solo el boton.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await asentar(tester);
      expect(api.paginasPedidas.length, tras);

      api.fallaPagina2 = false;
      await tester.tap(find.text('Cargar mas'));
      await asentar(tester);

      expect(find.text('Cargar mas'), findsNothing);
      expect(find.text('Aviso 10'), findsWidgets);
    });
  });
}
