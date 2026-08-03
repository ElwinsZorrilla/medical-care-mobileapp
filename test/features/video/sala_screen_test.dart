import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/video/data/lanzador_sala.dart';
import 'package:medicare/features/video/data/video_api.dart';
import 'package:medicare/features/video/data/video_dto.dart';
import 'package:medicare/features/video/data/video_repository.dart';
import 'package:medicare/features/video/presentation/providers/video_provider.dart';
import 'package:medicare/features/video/presentation/screens/sala_screen.dart';

/// La sala vista desde la pantalla — RF-35, RF-36, RF-37.
class _ApiFalsa extends VideoApi {
  _ApiFalsa({
    this.estado = 'PROGRAMADA',
    this.status,
    this.demora = Duration.zero,
  }) : super(Dio()) {
    // Una llamada que ya esta en curso tiene hora de inicio: el backend la
    // estampa al mover el estado. Sin esto no habria duracion que calcular al
    // finalizarla, y la prueba de la duracion pasaria por el motivo
    // equivocado.
    if (estado != 'PROGRAMADA') _inicio = '2026-08-17T12:02:00.000Z';
  }

  String estado;
  int? status;
  final Duration demora;

  final List<String> estadosPedidos = [];
  String? _inicio;
  String? _fin;

  DioException _error(int s) {
    final o = RequestOptions(path: '/appointments/7/videollamada');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: s),
      type: DioExceptionType.badResponse,
    );
  }

  VideollamadaDto _dto() => VideollamadaDto(
    idVideollamada: 1,
    idCita: 7,
    proveedor: 'JITSI',
    urlSala: 'https://meet.jit.si/medicare-3f1a',
    estado: estado,
    horaInicioReal: _inicio,
    horaFinReal: _fin,
  );

  @override
  Future<VideollamadaDto> crearOObtener(int idCita) async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error(status!);
    return _dto();
  }

  @override
  Future<VideollamadaDto> cambiarEstado(int idCita, String nuevo) async {
    estadosPedidos.add(nuevo);
    if (status != null) throw _error(status!);
    estado = nuevo;
    if (nuevo == 'EN_CURSO') _inicio = '2026-08-17T12:02:00.000Z';
    if (nuevo == 'FINALIZADA' || nuevo == 'FALLIDA') {
      _fin = '2026-08-17T12:28:00.000Z';
    }
    return _dto();
  }
}

class _LanzadorFalso implements LanzadorSala {
  _LanzadorFalso({this.puede = true});

  final bool puede;
  final List<String> abiertas = [];

  @override
  Future<bool> abrir(String url) async {
    abiertas.add(url);
    return puede;
  }
}

void main() {
  setUpAll(AppTime.init);

  late _LanzadorFalso lanzador;

  Future<void> asentar(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    String estado = 'PROGRAMADA',
    int? status,
    bool esMedico = false,
    bool puedeAbrir = true,
    Duration demora = Duration.zero,
    bool esperar = true,
  }) async {
    final api = _ApiFalsa(estado: estado, status: status, demora: demora);
    lanzador = _LanzadorFalso(puede: puedeAbrir);

    await tester.pumpWidget(
      ProviderScope(
        retry: PoliticaReintento.decidir,
        overrides: [
          videoRepositoryProvider.overrideWithValue(VideoRepository(api)),
          lanzadorSalaProvider.overrideWithValue(lanzador),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SalaScreen(idCita: 7, esMedico: esMedico),
        ),
      ),
    );
    if (esperar) await asentar(tester);
    return api;
  }

  group('los cuatro estados de la pantalla', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montar(tester, demora: const Duration(seconds: 5), esperar: false);
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('con datos muestra estado y proveedor', (tester) async {
      await montar(tester);

      expect(find.text('Cita #7'), findsOneWidget);
      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('JITSI'), findsOneWidget);
    });

    testWidgets('el error ofrece reintentar', (tester) async {
      final api = await montar(tester, status: 409);
      expect(find.byType(ErrorState), findsOneWidget);

      api.status = null;
      await tester.tap(find.text('Reintentar'));
      await asentar(tester);

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Cita #7'), findsOneWidget);
    });
  });

  group('RF-36 — la URL es un secreto', () {
    testWidgets('la sala no se pinta en ninguna parte', (tester) async {
      await montar(tester);

      // Cualquiera que vea la URL entra a la consulta. No hay enlace que
      // copiar, y eso se explica en pantalla para que no se lea como un bug.
      expect(find.textContaining('meet.jit.si'), findsNothing);
      expect(find.textContaining('medicare-3f1a'), findsNothing);
      expect(find.textContaining('cualquiera que lo tenga'), findsOneWidget);
    });
  });

  group('RF-35 — entrar', () {
    testWidgets('el boton abre la sala y marca EN_CURSO', (tester) async {
      final api = await montar(tester);

      await tester.tap(find.text('Entrar a la consulta'));
      await asentar(tester);

      expect(api.estadosPedidos, ['EN_CURSO']);
      expect(lanzador.abiertas, ['https://meet.jit.si/medicare-3f1a']);
      // El estado nuevo se refleja sin recargar la pantalla.
      expect(find.text('En curso'), findsOneWidget);
    });

    testWidgets('una consulta finalizada no ofrece entrar', (tester) async {
      await montar(tester, estado: 'FINALIZADA');

      expect(find.text('Entrar a la consulta'), findsNothing);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('La consulta termino'), findsOneWidget);
    });

    testWidgets('una fallida lo dice con otras palabras', (tester) async {
      await montar(tester, estado: 'FALLIDA');

      expect(find.text('La consulta no pudo realizarse'), findsOneWidget);
    });

    testWidgets('si no se puede abrir, avisa', (tester) async {
      await montar(tester, puedeAbrir: false);

      await tester.tap(find.text('Entrar a la consulta'));
      await asentar(tester);

      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('RF-37 — cerrar la consulta es del medico', () {
    testWidgets('el paciente no ve los controles de estado', (tester) async {
      await montar(tester, estado: 'EN_CURSO');

      // Salir de la llamada no puede darla por terminada para los dos.
      expect(find.text('Finalizar consulta'), findsNothing);
      expect(find.text('Marcar como fallida'), findsNothing);
    });

    testWidgets('el medico finaliza y la pantalla lo refleja', (tester) async {
      final api = await montar(tester, estado: 'EN_CURSO', esMedico: true);

      await tester.tap(find.text('Finalizar consulta'));
      await asentar(tester);

      expect(api.estadosPedidos, ['FINALIZADA']);
      expect(find.text('Finalizada'), findsOneWidget);
      expect(find.text('La consulta termino'), findsOneWidget);
      // La duracion aparece cuando ya hay las dos horas.
      expect(find.text('26 min'), findsOneWidget);
    });

    testWidgets('desde PROGRAMADA no se ofrece finalizar', (tester) async {
      await montar(tester, esMedico: true);

      // Ese salto no existe: hay que pasar por EN_CURSO.
      expect(find.text('Finalizar consulta'), findsNothing);
      expect(find.text('Marcar como fallida'), findsOneWidget);
    });

    testWidgets('sobre una terminal no queda ningun control', (tester) async {
      await montar(tester, estado: 'FINALIZADA', esMedico: true);

      expect(find.text('Finalizar consulta'), findsNothing);
      expect(find.text('Marcar como fallida'), findsNothing);
    });

    testWidgets('un fallo al cambiar estado avisa y no miente', (tester) async {
      final api = await montar(tester, estado: 'EN_CURSO', esMedico: true);
      api.status = 409;

      await tester.tap(find.text('Finalizar consulta'));
      await asentar(tester);

      expect(find.byType(SnackBar), findsOneWidget);
      // Lo que se estaba mostrando sigue siendo cierto.
      expect(find.text('En curso'), findsOneWidget);
    });
  });
}
