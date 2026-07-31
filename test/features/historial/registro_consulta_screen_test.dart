import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/features/historial/domain/consulta.dart';
import 'package:medicare/features/historial/presentation/providers/historial_provider.dart';
import 'package:medicare/features/historial/presentation/screens/registro_consulta_screen.dart';

/// Registrar consulta — RF-25, RF-26.
///
/// La pantalla no existía hasta F15: `RegistroConsulta` estaba desde F09 con
/// sus pruebas y ningún widget lo invocaba, así que un médico no tenía dónde
/// escribir un diagnóstico aunque la matriz diera RF-25 por cumplido.
void main() {
  late SolicitudConsulta? enviada;

  setUp(() => enviada = null);

  Future<void> montar(WidgetTester tester, {Failure? fallo}) async {
    // Viewport alto: el formulario entero entra sin scroll. El listado es
    // perezoso, asi que con la pantalla por defecto el boton de guardar ni
    // siquiera esta construido y ningun finder lo alcanza. Lo que se prueba
    // aca es la logica del formulario, no el scroll.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: PoliticaReintento.decidir,
        overrides: [
          registroConsultaProvider.overrideWith(
            () => _RegistroFalso((s) {
              enviada = s;
              return fallo;
            }),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const RegistroConsultaScreen(idCita: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester) async {
    await tester.tap(find.text('Guardar consulta'));
    await tester.pumpAndSettle();
  }

  group('RF-25 — registrar la consulta', () {
    testWidgets('el diagnóstico es obligatorio', (tester) async {
      await montar(tester);
      await guardar(tester);

      // Sin diagnóstico el backend responde 400 y la cita no pasaría a
      // COMPLETADA: se corta antes de salir a la red.
      expect(enviada, isNull);
      expect(find.text('El diagnóstico es obligatorio.'), findsOneWidget);
    });

    testWidgets('camino feliz: manda el diagnóstico y el id de la cita', (
      tester,
    ) async {
      await montar(tester);
      await tester.enterText(find.byType(TextField).first, 'Faringitis');
      await guardar(tester);

      expect(enviada, isNotNull);
      expect(enviada!.idCita, 5);
      expect(enviada!.diagnostico, 'Faringitis');
    });

    testWidgets('los opcionales vacíos viajan como null', (tester) async {
      // Mandar cadenas vacías guardaría un tratamiento en blanco en la
      // historia clínica en vez de dejarlo ausente.
      await montar(tester);
      await tester.enterText(find.byType(TextField).first, 'Faringitis');
      await guardar(tester);

      expect(enviada!.tratamiento, isNull);
      expect(enviada!.observaciones, isNull);
    });

    testWidgets('avisa que la cita queda completada antes de guardar', (
      tester,
    ) async {
      // El efecto es irreversible: el backend no expone transición de vuelta.
      await montar(tester);
      expect(
        find.textContaining('queda marcada como completada'),
        findsOneWidget,
      );
    });

    testWidgets('camino de error: muestra el mensaje del servidor', (
      tester,
    ) async {
      await montar(
        tester,
        fallo: const Prohibido('Solo el médico tratante registra la consulta.'),
      );
      await tester.enterText(find.byType(TextField).first, 'Faringitis');
      await guardar(tester);

      expect(find.textContaining('médico tratante'), findsOneWidget);
    });
  });

  group('RF-26 — recetas', () {
    testWidgets('empieza sin recetas', (tester) async {
      await montar(tester);
      expect(find.text('Recetas (0)'), findsOneWidget);
    });

    testWidgets('una receta necesita los tres campos', (tester) async {
      await montar(tester);
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Agregar'),
        ),
      );
      await tester.pumpAndSettle();

      // Una receta sin dosis ni frecuencia no le dice nada al paciente.
      expect(find.text('Obligatorio.'), findsNWidgets(3));
    });

    testWidgets('la receta viaja en la MISMA llamada que la consulta', (
      tester,
    ) async {
      // Dos peticiones dejarían una consulta sin sus recetas si la segunda
      // falla.
      await montar(tester);
      await tester.enterText(find.byType(TextField).first, 'Faringitis');

      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();
      // Acotado al dialogo: la pantalla de atras tambien tiene TextFields, y
      // sin esto se escribiria en el diagnostico.
      final campos = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(campos.at(0), 'Amoxicilina');
      await tester.enterText(campos.at(1), '500mg');
      await tester.enterText(campos.at(2), 'c/8h');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Agregar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recetas (1)'), findsOneWidget);
      expect(find.text('Amoxicilina'), findsOneWidget);

      await guardar(tester);

      expect(enviada!.recetas, hasLength(1));
      expect(enviada!.recetas.single.medicamento, 'Amoxicilina');
      expect(enviada!.recetas.single.frecuencia, 'c/8h');
    });
  });
}

class _RegistroFalso extends RegistroConsulta {
  _RegistroFalso(this.alRegistrar);

  final Failure? Function(SolicitudConsulta) alRegistrar;

  @override
  void build() {}

  @override
  Future<Object?> registrar(SolicitudConsulta solicitud) async =>
      alRegistrar(solicitud);
}
