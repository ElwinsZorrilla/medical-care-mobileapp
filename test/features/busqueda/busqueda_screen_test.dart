import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/domain/pagina.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/busqueda/data/busqueda_api.dart';
import 'package:medicare/features/busqueda/data/busqueda_dto.dart';
import 'package:medicare/features/busqueda/data/busqueda_repository.dart';
import 'package:medicare/features/busqueda/presentation/providers/busqueda_provider.dart';
import 'package:medicare/features/busqueda/presentation/screens/busqueda_screen.dart';

/// Devuelve páginas **llenas** a propósito.
///
/// Con un médico por página la lista nunca desborda la pantalla, no hay
/// scroll, y el RF-15 quedaría "probado" llamando al provider a mano. Con
/// páginas llenas el gesto de scroll es real y lo que se prueba es la
/// pantalla, no el notifier.
class _ApiFalsa extends BusquedaApi {
  _ApiFalsa({
    this.total = 1,
    this.statusMedicos,
    this.statusEspecialidades,
    this.demora = Duration.zero,
    this.fallaPagina2 = false,
  }) : super(Dio());

  final int total;
  final int? statusMedicos;
  // Mutable: una prueba lo apaga para verificar que el reintento del filtro
  // de verdad recupera el catálogo.
  int? statusEspecialidades;
  final Duration demora;
  final bool fallaPagina2;

  int? especialidadPedida;
  final List<int> paginasPedidas = [];

  DioException _error(int status) {
    final o = RequestOptions(path: '/doctors');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<List<CatalogoEspecialidadDto>> especialidades() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (statusEspecialidades != null) throw _error(statusEspecialidades!);
    return const [
      CatalogoEspecialidadDto(idEspecialidad: 1, nombre: 'Medicina General'),
      CatalogoEspecialidadDto(idEspecialidad: 4, nombre: 'Cardiología'),
    ];
  }

  @override
  Future<PaginaMedicosDto> medicos({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
    int? especialidadId,
  }) async {
    paginasPedidas.add(pagina);
    especialidadPedida = especialidadId;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (statusMedicos != null) throw _error(statusMedicos!);
    if (fallaPagina2 && pagina == 2) throw _error(500);

    final desde = (pagina - 1) * limite;
    final cuantos = math.max(0, math.min(limite, total - desde));

    return PaginaMedicosDto(
      data: [
        for (var i = 0; i < cuantos; i++)
          MedicoDto(
            idMedico: desde + i,
            idUsuario: 100 + desde + i,
            // Numeración global: así se distingue un médico de la página 2 de
            // uno de la página 1 y se puede probar que la lista acumula.
            nombres: 'Ana${desde + i}',
            apellidos: 'Gómez',
            numExequatur: 'EXQ-${desde + i}',
            estadoVerificacion: 'VERIFICADO',
            especialidades: const [
              EspecialidadDto(idEspecialidad: 4, nombre: 'Cardiología'),
            ],
            tarifaConsulta: 1500,
          ),
      ],
      total: total,
      page: pagina,
      limit: limite,
    );
  }
}

void main() {
  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    int total = 1,
    int? statusMedicos,
    int? statusEspecialidades,
    Duration demora = Duration.zero,
    bool fallaPagina2 = false,
    bool asentar = true,
  }) async {
    final api = _ApiFalsa(
      total: total,
      statusMedicos: statusMedicos,
      statusEspecialidades: statusEspecialidades,
      demora: demora,
      fallaPagina2: fallaPagina2,
    );
    await tester.pumpWidget(
      ProviderScope(
        // La misma que usa `main.dart`. Con el default de Riverpod, un fallo
        // se queda en `AsyncLoading` ~38 s y el `ErrorState` nunca aparece
        // dentro de la prueba: quedaría verificando algo que la app no hace.
        retry: PoliticaReintento.decidir,
        overrides: [
          busquedaRepositoryProvider.overrideWithValue(BusquedaRepository(api)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // La pulsación del skeleton es `repeat(reverse: true)`: mientras uno
          // esté montado, `pumpAndSettle` nunca asienta. Se usa la misma vía
          // de accesibilidad que el widget ya respeta —lo que ve un usuario
          // con "reducir movimiento"— en vez de agregarle un hook de prueba.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const BusquedaScreen(),
        ),
      ),
    );
    if (asentar) {
      await tester.pumpAndSettle();
      // Con las animaciones apagadas no queda ningún frame agendado, así que
      // `pumpAndSettle` vuelve con los reintentos todavía pendientes. Hay que
      // dejarlos correr para ver el estado final.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
    return api;
  }

  /// El listado vertical. Hay dos `Scrollable` en pantalla —el filtro de
  /// especialidades es horizontal— y solo este contiene tarjetas.
  Finder lista() => find
      .ancestor(
        of: find.byType(AppCard).first,
        matching: find.byType(Scrollable),
      )
      .first;

  /// Arrastra el listado hacia arriba, como haría un pulgar.
  Future<void> scrollear(WidgetTester tester, {double px = 600}) async {
    await tester.drag(find.byType(AppCard).first, Offset(0, -px));
    await tester.pumpAndSettle();
  }

  Future<void> scrollearHasta(WidgetTester tester, Finder objetivo) =>
      tester.scrollUntilVisible(objetivo, 300, scrollable: lista());

  group('los cuatro estados', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montar(
        tester,
        demora: const Duration(milliseconds: 50),
        asentar: false,
      );
      await tester.pump();

      // El filtro pinta su propio skeleton mientras carga el catálogo, así que
      // `findsWidgets` a secas seguiría verde aunque el cuerpo de la lista se
      // quedara en blanco. Se busca dentro del cuerpo.
      expect(
        find.descendant(
          of: find.byType(Expanded),
          matching: find.byType(LoadingSkeleton),
        ),
        findsWidgets,
      );
      expect(find.byType(AppCard), findsNothing);

      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('sin resultados sugiere quitar el filtro', (tester) async {
      await montar(tester, total: 0);

      expect(find.byType(EmptyState), findsOneWidget);
      // Un "no hay nada" a secas deja al usuario sin salida: el filtro que
      // acaba de poner es justamente lo que vació la lista.
      expect(find.textContaining('quita el filtro'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, statusMedicos: 500);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('reintentar vuelve a pedir la página 1', (tester) async {
      final api = await montar(tester, statusMedicos: 500);
      api.paginasPedidas.clear();

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(api.paginasPedidas, contains(1));
    });
  });

  group('RF-12 — catálogo como filtro', () {
    testWidgets('muestra las especialidades más la opción Todas', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Medicina General'), findsOneWidget);
      expect(find.text('Cardiología'), findsWidgets);
    });

    testWidgets('si el catálogo falla, la búsqueda sigue funcionando', (
      tester,
    ) async {
      // Tumbar la pantalla entera sería peor: sin filtro, el listado completo
      // todavía sirve.
      await montar(tester, statusEspecialidades: 500);

      expect(find.text('Todas'), findsNothing);
      expect(find.byType(AppCard), findsWidgets);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('pero el filtro no desaparece en silencio', (tester) async {
      // `catalogoEspecialidades` es `keepAlive`: sin una salida propia, un
      // bache de red al abrir la pantalla deja al usuario sin filtro por el
      // resto de la sesión. El "Reintentar" de la lista no lo recupera.
      final api = await montar(tester, statusEspecialidades: 500);

      expect(find.text('Cargar especialidades'), findsOneWidget);

      api.statusEspecialidades = null;
      await tester.tap(find.text('Cargar especialidades'));
      await tester.pumpAndSettle();

      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Medicina General'), findsOneWidget);
    });
  });

  group('RF-13, RF-14 — filtro por especialidad', () {
    testWidgets('la tarjeta muestra la especialidad del médico', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Dr. Ana0 Gómez'), findsOneWidget);
      // RF-13: la relación médico ↔ especialidad, visible **en la tarjeta**.
      // Sin acotar el finder, el chip del filtro también dice "Cardiología" y
      // la prueba pasaría aunque se borrara el texto de la tarjeta.
      expect(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.text('Cardiología'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tocar una especialidad la manda al backend', (tester) async {
      final api = await montar(tester);
      expect(api.especialidadPedida, isNull);

      await tester.tap(find.widgetWithText(InkWell, 'Cardiología').first);
      await tester.pumpAndSettle();

      expect(api.especialidadPedida, 4);
    });

    testWidgets('volver a Todas quita el filtro', (tester) async {
      final api = await montar(tester);

      await tester.tap(find.widgetWithText(InkWell, 'Cardiología').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(InkWell, 'Todas'));
      await tester.pumpAndSettle();

      expect(api.especialidadPedida, isNull);
    });

    testWidgets('cambiar de filtro reinicia en la página 1', (tester) async {
      // Si conservara la página, filtrar estando en la 3 mostraría un listado
      // que empieza por la mitad.
      final api = await montar(tester, total: 40);
      await scrollear(tester);
      expect(api.paginasPedidas, contains(2));
      api.paginasPedidas.clear();

      await tester.tap(find.widgetWithText(InkWell, 'Cardiología').first);
      await tester.pumpAndSettle();

      expect(api.paginasPedidas.first, 1);
    });
  });

  group('RF-15 — scroll infinito', () {
    testWidgets('scrollear cerca del final pide la página siguiente', (
      tester,
    ) async {
      final api = await montar(tester, total: 40);
      expect(api.paginasPedidas, [1]);

      await scrollear(tester);

      expect(api.paginasPedidas, contains(2));
    });

    testWidgets('la lista acumula, no reemplaza', (tester) async {
      await montar(tester, total: 40);
      await scrollear(tester);

      // Ana10 es el primero de la página 2; si reemplazara, Ana0 ya no
      // estaría en la lista.
      await scrollearHasta(tester, find.text('Dr. Ana10 Gómez'));
      expect(find.text('Dr. Ana10 Gómez'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Dr. Ana0 Gómez'),
        -300,
        scrollable: lista(),
      );
      expect(find.text('Dr. Ana0 Gómez'), findsOneWidget);
    });

    testWidgets('con una sola página no pide más', (tester) async {
      final api = await montar(tester, total: 5);

      await scrollear(tester);

      expect(api.paginasPedidas, [1]);
    });

    testWidgets('no pide la misma página dos veces a la vez', (tester) async {
      // El listener del scroll dispara en cada frame del arrastre; sin el
      // candado del provider se pediría la 2 varias veces.
      final api = await montar(
        tester,
        total: 40,
        demora: const Duration(milliseconds: 30),
      );
      api.paginasPedidas.clear();

      await tester.drag(find.byType(AppCard).first, const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(api.paginasPedidas.where((p) => p == 2), hasLength(1));
    });

    testWidgets('si falla la página siguiente no se pierde lo cargado', (
      tester,
    ) async {
      // Un AsyncError global cambiaría la pantalla entera por un mensaje y
      // le borraría al usuario la lista y el scroll.
      await montar(tester, total: 40, fallaPagina2: true);

      await scrollear(tester);

      expect(find.byType(ErrorState), findsNothing);
      expect(find.byType(AppCard), findsWidgets);
      await scrollearHasta(tester, find.text('Cargar más'));
      expect(find.text('Cargar más'), findsOneWidget);
    });

    testWidgets('el pie reintenta solo la página que falló', (tester) async {
      final api = await montar(tester, total: 40, fallaPagina2: true);
      await scrollear(tester);
      await scrollearHasta(tester, find.text('Cargar más'));
      api.paginasPedidas.clear();

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();

      expect(api.paginasPedidas, contains(2));
      // Recargar todo desde la 1 perdería el scroll del usuario.
      expect(api.paginasPedidas, isNot(contains(1)));
    });
  });

  group('presentación', () {
    testWidgets('la tarifa se pinta con el prefijo de moneda', (tester) async {
      await montar(tester);

      expect(find.text(r'RD$1500'), findsOneWidget);
    });
  });
}
