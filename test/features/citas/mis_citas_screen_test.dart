import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_directorio.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/citas/data/citas_api.dart';
import 'package:medicare/features/citas/data/citas_dto.dart';
import 'package:medicare/features/citas/data/citas_repository.dart';
import 'package:medicare/features/citas/presentation/providers/citas_provider.dart';
import 'package:medicare/features/citas/presentation/screens/mis_citas_screen.dart';

class _ApiFalsa extends CitasApi {
  _ApiFalsa({
    this.citas = const [],
    this.status,
    this.demora = Duration.zero,
    this.errorAlCancelar,
  }) : super(Dio());

  final List<CitaDto> citas;
  final int? status;
  final Duration demora;
  final int? errorAlCancelar;

  String? motivoRecibido;

  DioException _error(int codigo, String mensaje) {
    final o = RequestOptions(path: '/appointments');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: codigo,
        data: {'message': mensaje},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<PaginaCitasDto> misCitas({int pagina = 1, int limite = 10}) async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error(status!, 'boom');
    return PaginaCitasDto(
      data: citas,
      total: citas.length,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<PaginaCitasDto> miAgenda({int pagina = 1, int limite = 10}) =>
      misCitas(pagina: pagina, limite: limite);

  @override
  Future<CitaDto> cancelar(int idCita, String motivo) async {
    motivoRecibido = motivo;
    if (errorAlCancelar != null) {
      throw _error(errorAlCancelar!, 'La cita ya estaba cancelada');
    }
    return citas.first;
  }
}

CitaDto cita({
  int id = 1,
  String estado = 'PENDIENTE',
  String? motivo = 'Dolor de cabeza',
}) => CitaDto(
  idCita: id,
  idPaciente: 1,
  idMedico: 2,
  fechaHoraInicio: '2026-08-17T12:00:00.000Z',
  fechaHoraFin: '2026-08-17T12:30:00.000Z',
  modalidad: 'PRESENCIAL',
  estado: estado,
  fechaCreacion: '2026-07-31T01:03:39.194Z',
  motivoConsulta: motivo,
);

/// Transporte que responde 404 a `/doctors/{id}`.
///
/// Sin esto, `MedicoDirectorio` sale a la red de verdad: los tests tardaban
/// entre 15 y 30 segundos esperando timeouts. Un 404 hace que el directorio
/// devuelva null de inmediato, que es justo el caso que interesa probar —la
/// cita se pinta igual aunque el nombre no se resuelva.
class _SinDirectorio implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 404);

  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() async => AppTime.init());

  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    List<CitaDto> citas = const [],
    int? status,
    Duration demora = Duration.zero,
    int? errorAlCancelar,
    bool agenda = false,
    bool asentar = true,
  }) async {
    final api = _ApiFalsa(
      citas: citas,
      status: status,
      demora: demora,
      errorAlCancelar: errorAlCancelar,
    );
    await tester.pumpWidget(
      ProviderScope(
        // La misma politica que main.dart. Con el default de Riverpod un
        // fallo se queda en AsyncLoading ~38 s y el ErrorState no llega a
        // pintarse: la prueba verificaria algo que la app no hace.
        retry: PoliticaReintento.decidir,
        overrides: [
          citasRepositoryProvider.overrideWithValue(CitasRepository(api)),
          medicoDirectorioProvider.overrideWithValue(
            MedicoDirectorio(Dio()..httpClientAdapter = _SinDirectorio()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MisCitasScreen(agenda: agenda),
        ),
      ),
    );
    if (asentar) await tester.pumpAndSettle();
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
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('vacío invita a buscar médico', (tester) async {
      await montar(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('Busca un médico'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, status: 500);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('RF-23 — el riel de estado', () {
    testWidgets('cada cita se pinta con su riel', (tester) async {
      await montar(tester, citas: [cita()]);

      expect(find.byType(StatusRail), findsOneWidget);
      expect(find.text('PENDIENTE'), findsWidgets);
    });

    testWidgets('la hora se pinta en local, no en UTC', (tester) async {
      // 12:00Z es 08:00 en Santo Domingo. Pintar 12:00 sería el bug de
      // RNF-18 llegando hasta la pantalla.
      await montar(tester, citas: [cita()]);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('el estado lleva glifo además de color', (tester) async {
      await montar(tester, citas: [cita()]);
      // ○ = pendiente. El color solo nunca comunica estado.
      expect(find.text('○'), findsWidgets);
    });

    testWidgets('filtra por estado sobre lo cargado', (tester) async {
      await montar(
        tester,
        citas: [
          cita(estado: 'PENDIENTE'),
          cita(id: 2, estado: 'CANCELADA'),
        ],
      );
      expect(find.byType(StatusRail), findsNWidgets(2));

      // El filtro es del lado cliente: el backend no acepta ?estado=.
      await tester.tap(find.widgetWithText(InkWell, 'CANCELADA').first);
      await tester.pumpAndSettle();

      expect(find.byType(StatusRail), findsOneWidget);
    });
  });

  group('RF-22 — cancelar con motivo', () {
    testWidgets('una cita terminal no ofrece cancelar', (tester) async {
      await montar(tester, citas: [cita(estado: 'CANCELADA')]);
      expect(find.text('Cancelar cita'), findsNothing);
    });

    testWidgets('el motivo es obligatorio', (tester) async {
      final api = await montar(tester, citas: [cita()]);

      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();

      // Confirmar con el campo vacío no llama al backend.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar cita'));
      await tester.pumpAndSettle();

      expect(find.text('Cuéntanos por qué cancelas.'), findsOneWidget);
      expect(api.motivoRecibido, isNull);
    });

    testWidgets('con motivo sí cancela', (tester) async {
      final api = await montar(tester, citas: [cita()]);

      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Me surgió un imprevisto');
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar cita'));
      await tester.pumpAndSettle();

      expect(api.motivoRecibido, 'Me surgió un imprevisto');
    });

    testWidgets('volver no cancela nada', (tester) async {
      final api = await montar(tester, citas: [cita()]);

      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();

      expect(api.motivoRecibido, isNull);
    });
  });

  group('agenda del médico', () {
    testWidgets('usa el título y el vacío propios del rol', (tester) async {
      await montar(tester, agenda: true);

      expect(find.text('Mi agenda'), findsWidgets);
      expect(find.textContaining('Cuando un paciente reserve'), findsOneWidget);
      // El médico no busca médicos: sin botón flotante.
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('el nombre del médico', () {
    testWidgets('si no se resolvió, la cita se pinta igual', (tester) async {
      // Fecha, hora y estado ya son útiles. Bloquear la lista por un nombre
      // que no llegó sería peor que mostrarla incompleta.
      await montar(tester, citas: [cita()]);

      expect(find.textContaining('Médico #2'), findsOneWidget);
      expect(find.byType(StatusRail), findsOneWidget);
    });
  });
}
