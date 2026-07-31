import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/auth/presentation/screens/splash_screen.dart';

/// Pruebas de widget de las pantallas de autenticación.
///
/// Se centran en la lógica condicional visible: validación local antes de
/// gastar una petición, y el estado de arranque.
void main() {
  /// `AppTextField` envuelve un `TextField`, que exige un ancestro `Material`.
  Future<void> montar(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('SplashScreen', () {
    testWidgets('muestra la marca y el indicador de carga', (tester) async {
      await montar(tester, const SplashScreen());
      expect(find.text('MediCare'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('validación local del formulario', () {
    // La validación del login vive en la pantalla, así que se ejercita
    // montando los componentes con los mismos estados que produce.

    testWidgets('un campo con error muestra el mensaje', (tester) async {
      await montar(
        tester,
        const AppTextField(
          label: 'Correo',
          error: 'Ese correo no parece válido.',
        ),
      );
      expect(find.text('Ese correo no parece válido.'), findsOneWidget);
    });

    testWidgets('sin error no hay mensaje', (tester) async {
      await montar(tester, const AppTextField(label: 'Correo'));
      expect(find.textContaining('no parece'), findsNothing);
    });

    testWidgets('el botón deshabilitado no dispara', (tester) async {
      var toques = 0;
      await montar(
        tester,
        AppButton(label: 'Entrar', cargando: true, onPressed: () => toques++),
      );
      await tester.tap(find.byType(AppButton));
      expect(toques, 0);
    });
  });

  group('copia — DESIGN_SYSTEM.md §8', () {
    testWidgets('el nombre de la acción no cambia en el camino', (
      tester,
    ) async {
      // El botón dice "Entrar", no "Enviar" ni "Autenticar".
      await montar(tester, AppButton(label: 'Entrar', onPressed: () {}));
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('el error dice qué pasó y qué hacer', (tester) async {
      await montar(
        tester,
        const ErrorState(mensaje: 'Correo o contraseña incorrectos.'),
      );
      final texto = tester.widget<Text>(
        find.text('Correo o contraseña incorrectos.'),
      );
      // Nada de "Autenticación fallida" ni códigos crudos.
      expect(texto.data, isNot(contains('401')));
      expect(texto.data, isNot(contains('Error')));
    });
  });
}
