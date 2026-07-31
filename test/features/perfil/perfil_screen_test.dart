import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/theme/app_theme.dart';
import 'package:medicare/core/widgets/widgets.dart';
import 'package:medicare/features/auth/domain/usuario.dart';
import 'package:medicare/features/auth/presentation/providers/auth_provider.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_dto.dart';
import 'package:medicare/features/perfil/data/perfil_repository.dart';
import 'package:medicare/features/perfil/domain/perfil.dart';
import 'package:medicare/features/perfil/presentation/providers/perfil_provider.dart';
import 'package:medicare/features/perfil/presentation/screens/perfil_screen.dart';
import 'package:medicare/features/perfil/presentation/widgets/badge_verificacion.dart';

/// API falsa.
///
/// Se falsea el repositorio y no el provider: así el test recorre el código
/// real del provider —incluido el mapeo de `Result` a `AsyncValue`— en vez de
/// saltárselo. Además evita depender de cuántos turnos de microtask hacen
/// falta para que un `Future.error` llegue a `AsyncError`.
class _ApiFalsa extends PerfilApi {
  _ApiFalsa({
    this.status,
    this.estadoMedico = 'PENDIENTE',
    this.demora = Duration.zero,
  }) : super(Dio());

  /// Latencia simulada. Sin ella la respuesta llega en el mismo frame y no
  /// existe un estado de carga observable que probar.
  final Duration demora;

  /// Si va, todas las llamadas fallan con ese código.
  final int? status;
  final String estadoMedico;

  DioException get _error {
    final o = RequestOptions(path: '/patients/me');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<PacienteDto> miPerfilPaciente() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error;
    return const PacienteDto(
      idPaciente: 3,
      idUsuario: 9,
      nombres: 'Juana',
      apellidos: 'Pérez',
      documentoIdentidad: '00112345678',
      fechaNacimiento: '1990-08-01',
      tipoSangre: 'O+',
      alergias: 'Penicilina',
    );
  }

  @override
  Future<MedicoDto> miPerfilMedico() async {
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (status != null) throw _error;
    return MedicoDto(
      idMedico: 5,
      idUsuario: 11,
      nombres: 'Alejandra',
      apellidos: 'Peña',
      numExequatur: '24-1877',
      estadoVerificacion: estadoMedico,
      especialidades: const [
        EspecialidadDto(idEspecialidad: 4, nombre: 'Cardiología'),
      ],
      tarifaConsulta: 1500,
    );
  }
}

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required TipoUsuario rol,
    int? status,
    String estadoMedico = 'PENDIENTE',
    bool asentar = true,
    Duration demora = Duration.zero,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sesionActualProvider.overrideWith(
            () => _SesionFalsa(Usuario(id: 9, correo: 'a@b.com', tipo: rol)),
          ),
          perfilRepositoryProvider.overrideWithValue(
            PerfilRepository(
              _ApiFalsa(
                status: status,
                estadoMedico: estadoMedico,
                demora: demora,
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PerfilScreen()),
      ),
    );
    if (asentar) await tester.pumpAndSettle();
  }

  group('resuelve por rol', () {
    testWidgets('el paciente ve sus datos clínicos', (tester) async {
      await montar(tester, rol: TipoUsuario.paciente);

      expect(find.text('Juana Pérez'), findsOneWidget);
      expect(find.text('TIPO DE SANGRE'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      // El badge de verificación es del médico: no debe aparecer.
      expect(find.byType(BadgeVerificacion), findsNothing);
    });

    testWidgets('el médico ve su verificación y credenciales', (tester) async {
      await montar(tester, rol: TipoUsuario.medico);

      expect(find.text('Dr. Alejandra Peña'), findsOneWidget);
      expect(find.byType(BadgeVerificacion), findsOneWidget);
      expect(find.text('24-1877'), findsOneWidget);
      expect(find.textContaining('Cardiología'), findsOneWidget);
    });

    testWidgets('la fecha de nacimiento se pinta sin correrse de día', (
      tester,
    ) async {
      await montar(tester, rol: TipoUsuario.paciente);
      // 1990-08-01 → 01/08/1990, no 31/07/1990.
      expect(find.text('01/08/1990'), findsOneWidget);
    });
  });

  group('los cuatro estados', () {
    testWidgets('cargando muestra skeleton, no spinner vacío', (tester) async {
      // Con latencia y sin asentar: se captura el frame con la petición en
      // vuelo, que es el estado que se quiere verificar.
      await montar(
        tester,
        rol: TipoUsuario.paciente,
        asentar: false,
        demora: const Duration(milliseconds: 50),
      );
      await tester.pump();

      expect(find.byType(LoadingSkeleton), findsWidgets);

      // Se deja terminar para no dejar un timer colgado.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    });

    testWidgets('sin perfil creado invita a completarlo', (tester) async {
      // 404 del backend. No es un error: es alguien que acaba de registrarse.
      await montar(tester, rol: TipoUsuario.paciente, status: 404);

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.textContaining('Aún no completas'), findsOneWidget);
      expect(find.byType(ErrorState), findsNothing);
    });

    testWidgets('error del servidor deja reintentar', (tester) async {
      await montar(tester, rol: TipoUsuario.paciente, status: 500);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('servidor'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('sin conexión también es un estado con salida', (tester) async {
      await montar(tester, rol: TipoUsuario.medico, status: 503);

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('estado de verificación desconocido no pinta badge falso', (
      tester,
    ) async {
      // Preferible un error visible a un badge equivocado: un médico
      // rechazado que se cree verificado esperaría pacientes que no llegan.
      await montar(tester, rol: TipoUsuario.medico, estadoMedico: 'EN_TRAMITE');

      expect(find.byType(BadgeVerificacion), findsNothing);
      expect(find.byType(ErrorState), findsOneWidget);
    });
  });

  group('BadgeVerificacion — RF-11', () {
    testWidgets('muestra etiqueta, glifo y explicación', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BadgeVerificacion(estado: EstadoVerificacion.pendiente),
          ),
        ),
      );

      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(find.text('○'), findsOneWidget);
      // "Visible y explicado": el texto dice qué implica el estado.
      expect(
        find.textContaining('no aparece en las búsquedas'),
        findsOneWidget,
      );
    });

    testWidgets('los tres estados renderizan con su explicación', (
      tester,
    ) async {
      for (final e in EstadoVerificacion.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: BadgeVerificacion(estado: e)),
          ),
        );
        expect(find.text(e.etiqueta), findsOneWidget);
        expect(find.text(e.glifo), findsOneWidget);
      }
    });
  });
}

/// Sesión fija, para no depender de `SecureStore` en un test de widget.
class _SesionFalsa extends SesionActual {
  _SesionFalsa(this._usuario);

  final Usuario _usuario;

  @override
  Sesion build() => Sesion.autenticada(_usuario);
}
