import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/fecha_calendario.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_dto.dart';
import 'package:medicare/features/perfil/data/perfil_repository.dart';
import 'package:medicare/features/perfil/presentation/providers/perfil_provider.dart';

/// RF-10 — reportado en uso real: completar el perfil de paciente tiraba
/// `Cannot use the Ref of edicionPerfilProvider after it has been disposed.`
///
/// `EdicionPerfilScreen` solo hace `ref.read(edicionPerfilProvider.notifier)`
/// —nunca `ref.watch`— así que el provider no tenía listeners propios. Un
/// `@riverpod` (autoDispose) sin listeners se desecha en cuanto Riverpod
/// revisa el conteo, y con una petición de red lo bastante lenta esa revisión
/// pasa **antes** de que el `await` termine: el `ref.invalidate` de después
/// usa un `Ref` ya muerto. Con `keepAlive: true` el provider sobrevive a la
/// espera aunque nadie lo watchee.
class _ApiLenta extends PerfilApi {
  _ApiLenta({this.demora = const Duration(milliseconds: 20)}) : super(Dio());

  final Duration demora;

  static const _paciente = PacienteDto(
    idPaciente: 1,
    idUsuario: 3,
    nombres: 'Ana',
    apellidos: 'Gómez',
    documentoIdentidad: '00112223334',
    fechaNacimiento: '1990-05-10',
  );

  @override
  Future<PacienteDto> crearPerfilPaciente(CrearPacienteDto body) async {
    await Future<void>.delayed(demora);
    return _paciente;
  }

  @override
  Future<PacienteDto> actualizarPerfilPaciente(
    ActualizarPacienteDto body,
  ) async {
    await Future<void>.delayed(demora);
    return _paciente;
  }
}

void main() {
  ProviderContainer armar({
    Duration demora = const Duration(milliseconds: 20),
  }) {
    final contenedor = ProviderContainer(
      overrides: [
        perfilRepositoryProvider.overrideWithValue(
          PerfilRepository(_ApiLenta(demora: demora)),
        ),
      ],
    );
    addTearDown(contenedor.dispose);
    return contenedor;
  }

  final fechaNacimiento = FechaCalendario.parse('1990-05-10')!;

  Future<Object?> guardar(ProviderContainer c, {required bool existe}) => c
      .read(edicionPerfilProvider.notifier)
      .guardarPaciente(
        existe: existe,
        nombres: 'Ana',
        apellidos: 'Gómez',
        documentoIdentidad: '00112223334',
        fechaNacimiento: fechaNacimiento,
      );

  test('crear el perfil con una respuesta lenta no revienta el Ref', () async {
    // Nadie hace `ref.watch(edicionPerfilProvider)` en la pantalla real:
    // este contenedor tampoco lo escucha, a propósito, para reproducir
    // exactamente esa condición.
    final c = armar();

    final fallo = await guardar(c, existe: false);

    expect(fallo, isNull);
  });

  test(
    'actualizar el perfil con una respuesta lenta no revienta el Ref',
    () async {
      final c = armar();

      final fallo = await guardar(c, existe: true);

      expect(fallo, isNull);
    },
  );
}
