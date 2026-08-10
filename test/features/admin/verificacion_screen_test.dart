import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/admin/data/admin_api.dart';
import 'package:medicare/features/admin/data/admin_dto.dart';
import 'package:medicare/features/admin/data/admin_repository.dart';
import 'package:medicare/features/admin/presentation/providers/admin_provider.dart';
import 'package:medicare/features/admin/presentation/screens/verificacion_screen.dart';

class _ApiFalsa extends AdminApi {
  _ApiFalsa({
    this.total = 1,
    this.statusPendientes,
    this.demora = Duration.zero,
    this.falloVerificacion,
  }) : super(Dio());

  final int total;
  final int? statusPendientes;
  final Duration demora;
  final int? falloVerificacion;

  final List<int> paginasPedidas = [];
  int? idVerificado;
  int? idRechazado;

  /// Simula que el servidor ya no lo devuelve como PENDIENTE.
  bool _resuelto = false;

  DioException _error(int status, String path) {
    final o = RequestOptions(path: path);
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<PaginaMedicosAdminDto> pendientes({
    int pagina = 1,
    int limite = 10,
  }) async {
    paginasPedidas.add(pagina);
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (statusPendientes != null) throw _error(statusPendientes!, '/doctors');

    final hayPendiente = pagina == 1 && total > 0 && !_resuelto;
    return PaginaMedicosAdminDto(
      data: hayPendiente
          ? const [
              MedicoDto(
                idMedico: 1,
                idUsuario: 101,
                nombres: 'Carlos',
                apellidos: 'Ramírez',
                numExequatur: 'EXQ-1',
                estadoVerificacion: 'PENDIENTE',
              ),
            ]
          : const [],
      total: hayPendiente ? total : 0,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<MedicoDto> actualizarVerificacion({
    required int idMedico,
    required String estado,
  }) async {
    if (falloVerificacion != null) {
      throw _error(falloVerificacion!, '/doctors/$idMedico/verificacion');
    }
    if (estado == 'VERIFICADO') idVerificado = idMedico;
    if (estado == 'RECHAZADO') idRechazado = idMedico;
    _resuelto = true;

    return MedicoDto(
      idMedico: idMedico,
      idUsuario: 101,
      nombres: 'Carlos',
      apellidos: 'Ramírez',
      numExequatur: 'EXQ-1',
      estadoVerificacion: estado,
    );
  }
}

void main() {
  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    int total = 1,
    int? statusPendientes,
    Duration demora = Duration.zero,
    int? falloVerificacion,
    bool asentar = true,
  }) async {
    final api = _ApiFalsa(
      total: total,
      statusPendientes: statusPendientes,
      demora: demora,
      falloVerificacion: falloVerificacion,
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: PoliticaReintento.decidir,
        overrides: [
          adminRepositoryProvider.overrideWithValue(AdminRepository(api)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const VerificacionScreen(),
        ),
      ),
    );
    if (asentar) {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
    return api;
  }

  group('los cuatro estados', () {
    testWidgets('cargando muestra skeleton', (tester) async {
      await montar(
        tester,
        demora: const Duration(milliseconds: 50),
        asentar: false,
      );
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);
      expect(find.byType(AppCard), findsNothing);

      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('sin pendientes invita a nada más', (tester) async {
      await montar(tester, total: 0);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No hay médicos pendientes'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, statusPendientes: 500);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('reintentar vuelve a pedir la página 1', (tester) async {
      final api = await montar(tester, statusPendientes: 500);
      api.paginasPedidas.clear();

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(api.paginasPedidas, contains(1));
    });
  });

  group('RF-11 — verificar y rechazar', () {
    testWidgets('la tarjeta muestra nombre y exequátur', (tester) async {
      await montar(tester);

      expect(find.text('Dr. Carlos Ramírez'), findsOneWidget);
      expect(find.text('Exequátur EXQ-1'), findsOneWidget);
      expect(find.text('Verificar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });

    testWidgets('tocar Verificar llama al backend con ese médico', (
      tester,
    ) async {
      final api = await montar(tester);

      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(api.idVerificado, 1);
    });

    testWidgets('tocar Rechazar llama al backend con ese médico', (
      tester,
    ) async {
      final api = await montar(tester);

      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();

      expect(api.idRechazado, 1);
    });

    testWidgets('al verificar bien, el médico desaparece de la cola', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      // La cola se recarga tras la acción; sin pendientes, queda el vacío.
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('si falla, avisa y no lo saca de la cola', (tester) async {
      await montar(tester, falloVerificacion: 403);

      await tester.tap(find.text('Verificar'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Carlos Ramírez'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
