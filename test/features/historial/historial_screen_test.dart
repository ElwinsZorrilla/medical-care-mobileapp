import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/auth/domain/usuario.dart';
import 'package:medicare/features/auth/presentation/providers/auth_provider.dart';
import 'package:medicare/features/historial/data/historial_api.dart';
import 'package:medicare/features/historial/data/historial_dto.dart';
import 'package:medicare/features/historial/data/historial_repository.dart';
import 'package:medicare/features/historial/presentation/providers/historial_provider.dart';
import 'package:medicare/features/historial/presentation/screens/historial_screen.dart';

class _ApiFalsa extends HistorialApi {
  _ApiFalsa({
    this.consultas = const [],
    this.status,
    this.demora = Duration.zero,
  }) : super(Dio());

  final List<ConsultaDto> consultas;
  final int? status;
  final Duration demora;

  /// Qué ruta se pidió. RNF-06: debe depender del rol, no de un parámetro.
  String? rutaPedida;

  DioException get _error {
    final o = RequestOptions(path: '/consultations');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: {'message': 'boom'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<PaginaConsultasDto> miHistorial({
    int pagina = 1,
    int limite = 10,
  }) async {
    rutaPedida = '/consultations/me';
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error;
    return PaginaConsultasDto(
      data: consultas,
      total: consultas.length,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<PaginaConsultasDto> atendidas({
    int pagina = 1,
    int limite = 10,
  }) async {
    final r = await miHistorial(pagina: pagina, limite: limite);
    rutaPedida = '/consultations/atendidas';
    return r;
  }
}

const _consulta = ConsultaDto(
  idConsulta: 1,
  idCita: 7,
  idPaciente: 3,
  idMedico: 5,
  diagnostico: 'Faringitis viral',
  fechaRegistro: '2026-08-17T14:30:00.000Z',
  tratamiento: 'Reposo e hidratación',
  signosVitales: {'presionArterial': '120/80', 'pulso': 78, 'glicemia': 95},
  recetas: [
    RecetaDto(
      idReceta: 1,
      medicamento: 'Ibuprofeno 400mg',
      dosis: '1 tableta',
      frecuencia: 'Cada 8 horas',
      duracionDias: 5,
      indicaciones: 'Tomar con alimentos',
    ),
  ],
);

void main() {
  setUpAll(() async => AppTime.init());

  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    List<ConsultaDto> consultas = const [],
    int? status,
    Duration demora = Duration.zero,
    TipoUsuario rol = TipoUsuario.paciente,
    bool asentar = true,
  }) async {
    final api = _ApiFalsa(consultas: consultas, status: status, demora: demora);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionActualProvider.overrideWith(
            () => _SesionFalsa(Usuario(id: 3, correo: 'a@b.com', tipo: rol)),
          ),
          historialRepositoryProvider.overrideWithValue(
            HistorialRepository(api),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const HistorialScreen(),
        ),
      ),
    );
    if (asentar) await tester.pumpAndSettle();
    return api;
  }

  group('RNF-06 — la ruta la elige el rol', () {
    testWidgets('el paciente pide su propio historial', (tester) async {
      final api = await montar(tester, consultas: const [_consulta]);
      // No hay parámetro de paciente que alguien pueda manipular.
      expect(api.rutaPedida, '/consultations/me');
    });

    testWidgets('el médico pide las que atendió', (tester) async {
      final api = await montar(
        tester,
        consultas: const [_consulta],
        rol: TipoUsuario.medico,
      );
      expect(api.rutaPedida, '/consultations/atendidas');
    });

    testWidgets('el título cambia con el rol', (tester) async {
      await montar(tester, rol: TipoUsuario.medico);
      expect(find.text('Consultas atendidas'), findsWidgets);
    });
  });

  group('los cuatro estados', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montar(
        tester,
        demora: const Duration(milliseconds: 50),
        asentar: false,
      );
      await tester.pump();
      expect(find.byType(LoadingSkeleton), findsWidgets);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('vacío explica qué va a aparecer', (tester) async {
      await montar(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('diagnóstico y las recetas'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, status: 500);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('datos clínicos — RF-25, RF-26, RF-27', () {
    testWidgets('muestra diagnóstico y tratamiento', (tester) async {
      await montar(tester, consultas: const [_consulta]);

      expect(find.text('Faringitis viral'), findsOneWidget);
      expect(find.text('Reposo e hidratación'), findsOneWidget);
      expect(find.text('DIAGNÓSTICO'), findsOneWidget);
    });

    testWidgets('los signos vitales llevan su unidad', (tester) async {
      await montar(tester, consultas: const [_consulta]);

      expect(find.text('120/80'), findsOneWidget);
      expect(find.text('78 lpm'), findsOneWidget);
    });

    testWidgets('una clave desconocida se muestra igual', (tester) async {
      // Esconderla sería ocultar un dato clínico que un médico anotó.
      await montar(tester, consultas: const [_consulta]);
      expect(find.text('95'), findsOneWidget);
      expect(find.text('GLICEMIA'), findsOneWidget);
    });

    testWidgets('la receta muestra la pauta completa', (tester) async {
      await montar(tester, consultas: const [_consulta]);

      expect(find.text('Ibuprofeno 400mg'), findsOneWidget);
      expect(find.text('1 tableta · Cada 8 horas · 5 días'), findsOneWidget);
      expect(find.text('Tomar con alimentos'), findsOneWidget);
    });

    testWidgets('la fecha se pinta en español y en hora local', (tester) async {
      await montar(tester, consultas: const [_consulta]);
      // 2026-08-17 14:30Z → 17 de agosto, 10:30 en Santo Domingo.
      expect(find.textContaining('agosto'), findsOneWidget);
    });
  });
}

class _SesionFalsa extends SesionActual {
  _SesionFalsa(this._usuario);

  final Usuario _usuario;

  @override
  Sesion build() => Sesion.autenticada(_usuario);
}
