import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/fecha_calendario.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/features/perfil/domain/perfil.dart';
import 'package:medicare/features/perfil/presentation/providers/perfil_provider.dart';
import 'package:medicare/features/perfil/presentation/screens/edicion_perfil_screen.dart';

/// Editar el perfil propio — RF-10.
///
/// La capa de datos existía desde F05 con sus pruebas y **ninguna pantalla la
/// llamaba**. RF-10 estuvo marcado como cubierto hasta que F15 recorrió `lib/`
/// buscando métodos públicos sin consumidor.
void main() {
  const paciente = PerfilPaciente(
    idPaciente: 3,
    idUsuario: 30,
    nombres: 'Luis',
    apellidos: 'Pérez',
    documentoIdentidad: '00112345678',
    fechaNacimiento: FechaCalendario(1990, 5, 2),
    tipoSangre: 'O+',
  );

  late _EdicionFalsa espia;

  Future<void> montar(
    WidgetTester tester, {
    PerfilPaciente? existente,
    Failure? fallo,
  }) async {
    espia = _EdicionFalsa(fallo);
    // Viewport alto: el formulario entero entra sin scroll y el boton de
    // guardar queda construido.
    tester.view
      ..physicalSize = const Size(800, 2600)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        retry: PoliticaReintento.decidir,
        overrides: [
          miPerfilPacienteProvider.overrideWith((ref) async => existente),
          edicionPerfilProvider.overrideWith(() => espia),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const EdicionPerfilScreen(tipo: TipoUsuario.paciente),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester, String etiqueta) async {
    await tester.tap(find.text(etiqueta));
    await tester.pumpAndSettle();
  }

  group('crear el perfil', () {
    testWidgets('sin perfil el botón dice crear', (tester) async {
      await montar(tester);
      expect(find.text('Crear perfil'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
    });

    testWidgets('exige nombres, apellidos, documento y nacimiento', (
      tester,
    ) async {
      await montar(tester);
      await guardar(tester, 'Crear perfil');

      // Se corta antes de salir a la red: el backend responderia 400.
      expect(espia.llamadas, 0);
      expect(find.text('Obligatorio.'), findsNWidgets(3));
      expect(find.text('Usa el formato AAAA-MM-DD.'), findsOneWidget);
    });

    testWidgets('rechaza una fecha con formato invalido', (tester) async {
      await montar(tester);
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Luis');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), '00112345678');
      await tester.enterText(campos.at(3), '02/05/1990');
      await guardar(tester, 'Crear perfil');

      expect(espia.llamadas, 0);
      expect(find.text('Usa el formato AAAA-MM-DD.'), findsOneWidget);
    });

    testWidgets('camino feliz: crea, no actualiza', (tester) async {
      await montar(tester);
      final campos = find.byType(TextField);
      await tester.enterText(campos.at(0), 'Luis');
      await tester.enterText(campos.at(1), 'Pérez');
      await tester.enterText(campos.at(2), '00112345678');
      await tester.enterText(campos.at(3), '1990-05-02');
      await guardar(tester, 'Crear perfil');

      expect(espia.llamadas, 1);
      // Son endpoints distintos: confundirlos da un 409 por documento
      // repetido.
      expect(espia.ultimoExiste, isFalse);
      expect(espia.ultimoDocumento, '00112345678');
    });
  });

  group('editar el perfil existente', () {
    testWidgets('precarga lo guardado', (tester) async {
      // Sin precargar, el PATCH mandaria vacios los campos que el usuario no
      // toca y borraria datos clinicos.
      await montar(tester, existente: paciente);

      expect(find.text('Luis'), findsOneWidget);
      expect(find.text('Pérez'), findsOneWidget);
      expect(find.text('1990-05-02'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets('el documento no se puede cambiar', (tester) async {
      // El backend lo fija al crear y no lo acepta en el PATCH.
      await montar(tester, existente: paciente);
      final documento = tester.widget<TextField>(find.byType(TextField).at(2));
      expect(documento.enabled, isFalse);
    });

    testWidgets('actualiza en vez de crear', (tester) async {
      await montar(tester, existente: paciente);
      await guardar(tester, 'Guardar cambios');

      expect(espia.llamadas, 1);
      expect(espia.ultimoExiste, isTrue);
    });

    testWidgets('un campo vaciado viaja como null, no como cadena vacia', (
      tester,
    ) async {
      await montar(tester, existente: paciente);
      // El de tipo de sangre es el quinto campo.
      await tester.enterText(find.byType(TextField).at(4), '');
      await guardar(tester, 'Guardar cambios');

      expect(espia.ultimoTipoSangre, isNull);
    });
  });

  group('caminos de error', () {
    testWidgets('muestra el mensaje del servidor sin borrar lo escrito', (
      tester,
    ) async {
      // Perder lo escrito por un 409 seria castigar al usuario por un
      // problema del servidor.
      await montar(
        tester,
        existente: paciente,
        fallo: const Conflicto('Ese documento ya está registrado.'),
      );
      await guardar(tester, 'Guardar cambios');

      expect(find.textContaining('ya está registrado'), findsOneWidget);
      expect(find.text('Luis'), findsOneWidget);
    });

    testWidgets('si el perfil no carga, deja reintentar', (tester) async {
      espia = _EdicionFalsa(null);
      await tester.pumpWidget(
        ProviderScope(
          retry: PoliticaReintento.decidir,
          overrides: [
            miPerfilPacienteProvider.overrideWith(
              (ref) async => throw const SinConexion(),
            ),
            edicionPerfilProvider.overrideWith(() => espia),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const EdicionPerfilScreen(tipo: TipoUsuario.paciente),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}

class _EdicionFalsa extends EdicionPerfil {
  _EdicionFalsa(this.fallo);

  final Failure? fallo;

  int llamadas = 0;
  bool? ultimoExiste;
  String? ultimoDocumento;
  String? ultimoTipoSangre;

  @override
  void build() {}

  @override
  Future<Failure?> guardarPaciente({
    required bool existe,
    required String nombres,
    required String apellidos,
    required String documentoIdentidad,
    required FechaCalendario fechaNacimiento,
    String? sexo,
    String? direccion,
    String? tipoSangre,
    String? alergias,
    String? seguroMedico,
  }) async {
    llamadas++;
    ultimoExiste = existe;
    ultimoDocumento = documentoIdentidad;
    ultimoTipoSangre = tipoSangre;
    return fallo;
  }
}
