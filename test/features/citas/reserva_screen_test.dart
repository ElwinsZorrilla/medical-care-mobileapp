import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/turnos_repository.dart';
import 'package:medicare/core/domain/modalidad.dart';
import 'package:medicare/core/domain/turno.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/network/result.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/time/app_time.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/citas/domain/cita.dart';
import 'package:medicare/features/citas/presentation/providers/citas_provider.dart';
import 'package:medicare/features/citas/presentation/screens/reserva_screen.dart';

/// Reservar — RF-18, RF-19, RF-20, RF-21.
///
/// La pantalla no existía hasta F15: `reservar` solo lo llamaban las pruebas,
/// así que RF-19 estaba marcado como cumplido sin que nadie pudiera reservar.
/// Estas pruebas cubren el camino feliz y **los tres conflictos** que el
/// backend mete en un mismo 409, que es lo que RF-20 pide distinguir.
void main() {
  Turno turno(String hora, {ModalidadFranja m = ModalidadFranja.presencial}) =>
      Turno(
        idDisponibilidad: 2,
        inicioUtc: DateTime.parse('2026-08-17T$hora:00:00.000Z').toUtc(),
        finUtc: DateTime.parse(
          '2026-08-17T$hora:00:00.000Z',
        ).toUtc().add(const Duration(minutes: 30)),
        modalidad: m,
        inicioApi: '2026-08-17T$hora:00:00.000Z',
      );

  /// Captura lo que se manda y devuelve el fallo que se le indique.
  late SolicitudReserva? enviada;
  late int vecesPedidosTurnos;

  setUpAll(AppTime.init);
  setUp(() {
    enviada = null;
    vecesPedidosTurnos = 0;
  });

  Future<void> montar(
    WidgetTester tester, {
    List<Turno>? turnos,
    Failure? errorTurnos,
    Failure? falloReserva,
    Duration demora = Duration.zero,
    bool asentar = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: PoliticaReintento.decidir,
        overrides: [
          // Se sobrescribe el repositorio y no el provider de familia: asi
          // corre la logica real del provider (incluido el `watch` del dia).
          turnosRepositoryProvider.overrideWithValue(
            _TurnosFalso(demora: demora, () {
              vecesPedidosTurnos++;
              if (errorTurnos != null) return Fallo(errorTurnos);
              return Ok(turnos ?? [turno('12'), turno('13')]);
            }),
          ),
          reservaProvider.overrideWith(
            () => _ReservaFalsa(
              alReservar: (s) {
                enviada = s;
                return falloReserva;
              },
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // El skeleton anima en bucle; sin esto `pumpAndSettle` no asienta.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const ReservaScreen(idMedico: 7),
        ),
      ),
    );
    if (asentar) {
      await tester.pumpAndSettle();
      // `SinConexion` y `ErrorServidor` se reintentan (PoliticaReintento), y
      // con las animaciones apagadas `pumpAndSettle` vuelve con los timers
      // pendientes. Hay que dejarlos correr para ver el estado final.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }
  }

  /// Elige el primer turno y confirma.
  Future<void> reservar(WidgetTester tester) async {
    await tester.tap(find.text('08:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar'));
    await tester.pumpAndSettle();
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

    testWidgets('sin turnos sugiere otra fecha', (tester) async {
      await montar(tester, turnos: const []);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('otra fecha'), findsOneWidget);
    });

    testWidgets('error deja reintentar', (tester) async {
      await montar(tester, errorTurnos: const SinConexion());
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('RF-18 — los turnos se pintan en hora local', () {
    testWidgets('12:00Z es 08:00 en Santo Domingo', (tester) async {
      await montar(tester);
      // Pintar la hora UTC mandaría al paciente cuatro horas tarde.
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('12:00'), findsNothing);
    });
  });

  group('RF-19, RF-21 — reservar', () {
    testWidgets('sin turno elegido no se puede confirmar', (tester) async {
      await montar(tester);
      // El botón ni siquiera aparece hasta que hay turno.
      expect(find.text('Reservar'), findsNothing);
    });

    testWidgets('manda el string crudo del servidor, no uno reconstruido', (
      tester,
    ) async {
      await montar(tester);
      await reservar(tester);

      expect(enviada, isNotNull);
      // Reconstruirlo desde el DateTime puede diferir en los milisegundos y
      // el backend no encontraría el turno.
      expect(enviada!.horaInicioApi, '2026-08-17T12:00:00.000Z');
      expect(enviada!.idMedico, 7);
    });

    testWidgets('el motivo viaja cuando se escribe — RF-21', (tester) async {
      await montar(tester);
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Dolor de pecho');
      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();

      expect(enviada!.motivoConsulta, 'Dolor de pecho');
    });

    testWidgets('vacío manda null y no una cadena vacía', (tester) async {
      await montar(tester);
      await reservar(tester);
      expect(enviada!.motivoConsulta, isNull);
    });
  });

  group('RF-20 — el 409 sobrecargado', () {
    testWidgets('turno tomado: refresca la grilla y avisa', (tester) async {
      await montar(
        tester,
        falloReserva: const Conflicto(
          'Ese turno ya lo tomaron. Elige otra hora.',
          mensajeServidor: 'El turno ya fue reservado',
        ),
      );
      final antes = vecesPedidosTurnos;

      await reservar(tester);

      // Se vuelve a pedir la grilla: la que se estaba viendo quedó vieja.
      expect(vecesPedidosTurnos, greaterThan(antes));
      expect(find.textContaining('ya lo tomaron'), findsOneWidget);
      // Y se pierde la selección, porque ese turno ya no existe.
      expect(find.text('Reservar'), findsNothing);
    });

    testWidgets('modalidad: conserva el turno y explica al lado', (
      tester,
    ) async {
      // Refrescar acá le borraría al usuario el turno que eligió sin arreglar
      // nada: lo que falla es la modalidad.
      await montar(
        tester,
        turnos: [turno('12', m: ModalidadFranja.ambas)],
        falloReserva: const Conflicto(
          'Ese turno solo admite modalidad PRESENCIAL.',
          mensajeServidor: 'modalidad no admitida',
        ),
      );
      final antes = vecesPedidosTurnos;

      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Presencial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();

      expect(vecesPedidosTurnos, antes, reason: 'no debe refrescar');
      expect(find.textContaining('solo admite modalidad'), findsOneWidget);
      // El turno sigue elegido: el botón sigue ahí.
      expect(find.text('Reservar'), findsOneWidget);
    });

    testWidgets('otro conflicto: solo muestra el mensaje', (tester) async {
      await montar(
        tester,
        falloReserva: const Conflicto(
          'Ya tienes una cita a esa hora.',
          mensajeServidor: 'solapamiento',
        ),
      );
      final antes = vecesPedidosTurnos;

      await reservar(tester);

      expect(vecesPedidosTurnos, antes);
      // En un SnackBar y no como error bajo la modalidad: sin acotar, este
      // finder no distinguiria `mostrarMensaje` de `corregirModalidad`.
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Ya tienes una cita'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nunca reintenta en silencio — RNF-10', (tester) async {
      // Un reintento automático volvería a pedir un turno que ya se sabe
      // tomado. La política de reintento debe dejar pasar el Conflicto.
      expect(
        PoliticaReintento.decidir(0, const Conflicto('x')),
        isNull,
        reason: 'un 409 de reserva no se reintenta',
      );
    });
  });

  group('cambiar de dia', () {
    testWidgets('suelta el turno elegido', (tester) async {
      // Sin esto la grilla se recarga con objetos nuevos, ningun chip aparece
      // marcado, pero la seleccion interna sigue apuntando al turno del dia
      // anterior: se mandaria la fecha nueva con el horaInicioApi viejo.
      await montar(tester);
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();
      expect(find.text('Reservar'), findsOneWidget);

      await tester.tap(find.byTooltip('Día siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Reservar'), findsNothing);
    });
  });

  group('modalidad', () {
    testWidgets('un turno PRESENCIAL no ofrece elegir', (tester) async {
      await montar(tester, turnos: [turno('12')]);
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();

      // Ofrecer las dos garantizaría un 409 evitable.
      expect(find.text('Virtual'), findsNothing);
      // Y queda lista para confirmar sin un paso de más.
      expect(find.text('Reservar'), findsOneWidget);
    });

    testWidgets('un turno AMBAS exige elegir antes de confirmar', (
      tester,
    ) async {
      await montar(tester, turnos: [turno('12', m: ModalidadFranja.ambas)]);
      await tester.tap(find.text('08:00'));
      await tester.pumpAndSettle();

      expect(find.text('Presencial'), findsOneWidget);
      expect(find.text('Virtual'), findsOneWidget);
      final boton = tester.widget<AppButton>(find.byType(AppButton));
      expect(boton.onPressed, isNull, reason: 'sin modalidad no se confirma');
    });
  });
}

class _TurnosFalso extends TurnosRepository {
  _TurnosFalso(this.respuesta, {this.demora = Duration.zero})
    : super(const _DioNulo());

  final Result<List<Turno>> Function() respuesta;
  final Duration demora;

  @override
  Future<Result<List<Turno>>> turnos({
    required int idMedico,
    required DateTime diaUtc,
  }) async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    return respuesta();
  }
}

/// Nunca se usa: el doble sobrescribe el unico metodo que sale a la red.
class _DioNulo implements Dio {
  const _DioNulo();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('el doble no sale a la red');
}

class _ReservaFalsa extends Reserva {
  _ReservaFalsa({required this.alReservar});

  final Failure? Function(SolicitudReserva) alReservar;

  @override
  void build() {}

  @override
  Future<Failure?> reservar(SolicitudReserva solicitud) async =>
      alReservar(solicitud);
}
