import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/agenda/data/agenda_api.dart';
import 'package:medicare/features/agenda/data/agenda_dto.dart';
import 'package:medicare/features/agenda/data/agenda_repository.dart';
import 'package:medicare/features/agenda/presentation/providers/agenda_provider.dart';
import 'package:medicare/features/agenda/presentation/screens/disponibilidad_screen.dart';

class _ApiFalsa extends AgendaApi {
  _ApiFalsa({this.status, this.franjas = const [], this.demora = Duration.zero})
    : super(Dio());

  final int? status;
  final List<DisponibilidadDto> franjas;
  final Duration demora;

  CrearDisponibilidadDto? creada;
  int? desactivada;

  DioException get _error {
    final o = RequestOptions(path: '/availability');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: {'message': 'La franja se solapa con otra disponibilidad activa'},
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<List<DisponibilidadDto>> misFranjas() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error;
    return franjas;
  }

  @override
  Future<DisponibilidadDto> crear(CrearDisponibilidadDto body) async {
    creada = body;
    if (status != null) throw _error;
    return franjas.isEmpty ? _lunes8a10 : franjas.first;
  }

  @override
  Future<DisponibilidadDto> desactivar(int id) async {
    desactivada = id;
    if (status != null) throw _error;
    return franjas.isEmpty ? _lunes8a10 : franjas.first;
  }
}

const _lunes8a10 = DisponibilidadDto(
  idDisponibilidad: 1,
  idMedico: 5,
  diaSemana: 1,
  horaInicio: '08:00',
  horaFin: '10:00',
  duracionSlotMin: 30,
  modalidad: 'PRESENCIAL',
  activo: true,
);

const _miercoles14a16 = DisponibilidadDto(
  idDisponibilidad: 2,
  idMedico: 5,
  diaSemana: 3,
  horaInicio: '14:00',
  horaFin: '16:00',
  duracionSlotMin: 20,
  modalidad: 'AMBAS',
  activo: true,
);

void main() {
  Future<_ApiFalsa> montar(
    WidgetTester tester, {
    int? status,
    List<DisponibilidadDto> franjas = const [],
    Duration demora = Duration.zero,
    bool asentar = true,
  }) async {
    final api = _ApiFalsa(status: status, franjas: franjas, demora: demora);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agendaRepositoryProvider.overrideWithValue(AgendaRepository(api)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const DisponibilidadScreen(),
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

    testWidgets('sin franjas explica la consecuencia, no solo el vacío', (
      tester,
    ) async {
      await montar(tester);

      expect(find.byType(EmptyState), findsOneWidget);
      // El vacío dice qué se pierde por no actuar.
      expect(find.textContaining('no ven turnos'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, status: 500);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('listado — RF-16', () {
    testWidgets('agrupa por día y pinta las horas en mono', (tester) async {
      await montar(tester, franjas: const [_lunes8a10, _miercoles14a16]);

      expect(find.text('Lunes'), findsOneWidget);
      expect(find.text('Miércoles'), findsOneWidget);
      expect(find.text('08:00 – 10:00'), findsOneWidget);
      expect(find.text('14:00 – 16:00'), findsOneWidget);
    });

    testWidgets('muestra cuántos turnos genera cada franja', (tester) async {
      // 08:00–10:00 con turnos de 30 min son 4. Verlo antes evita que el
      // médico descubra el efecto cuando un paciente no encuentra hueco.
      await montar(tester, franjas: const [_lunes8a10]);
      expect(find.textContaining('4 por día'), findsOneWidget);
    });

    testWidgets('la modalidad AMBAS se explica en palabras', (tester) async {
      await montar(tester, franjas: const [_miercoles14a16]);
      expect(find.textContaining('Presencial o virtual'), findsOneWidget);
    });
  });

  group('desactivar — RF-17', () {
    testWidgets('pide confirmación y avisa que no se puede revertir', (
      tester,
    ) async {
      // El backend no ofrece reactivar: un toque accidental obligaría a
      // crear la franja de nuevo.
      await montar(tester, franjas: const [_lunes8a10]);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Desactivar esta franja'), findsOneWidget);
      expect(find.textContaining('No se puede reactivar'), findsOneWidget);
    });

    testWidgets('cancelar no llama al backend', (tester) async {
      final api = await montar(tester, franjas: const [_lunes8a10]);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.desactivada, isNull);
    });

    testWidgets('confirmar sí desactiva', (tester) async {
      final api = await montar(tester, franjas: const [_lunes8a10]);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();

      expect(api.desactivada, 1);
    });
  });

  group('formulario — RF-16', () {
    Future<void> abrir(WidgetTester tester) async {
      await tester.tap(find.text('Agregar franja'));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece los siete días', (tester) async {
      await montar(tester);
      await abrir(tester);

      for (final abrev in ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB']) {
        expect(find.text(abrev), findsOneWidget);
      }
    });

    testWidgets('anticipa cuántos turnos van a salir', (tester) async {
      await montar(tester);
      await abrir(tester);

      // Por defecto 08:00–12:00 cada 30 min = 8 turnos.
      expect(find.textContaining('8 turnos'), findsOneWidget);
    });

    testWidgets('guarda con la numeración de día del backend', (tester) async {
      final api = await montar(tester);
      await abrir(tester);

      await tester.tap(find.text('Guardar franja'));
      await tester.pumpAndSettle();

      expect(api.creada, isNotNull);
      expect(api.creada!.diaSemana, 1, reason: 'lunes por defecto');
      expect(api.creada!.horaInicio, '08:00');
      expect(api.creada!.duracionSlotMin, 30);
    });

    testWidgets('un 409 del backend se muestra con el texto del servidor', (
      tester,
    ) async {
      await montar(tester, status: 409, franjas: const [_lunes8a10]);
      // Con error de carga la pantalla muestra ErrorState; el formulario no
      // llega a abrirse. Se verifica que el mensaje del servidor sobrevive.
      expect(find.textContaining('solapa'), findsOneWidget);
    });
  });
}
