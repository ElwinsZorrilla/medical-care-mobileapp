import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/features/perfil/data/perfil_api.dart';
import 'package:medicare/features/perfil/data/perfil_dto.dart';
import 'package:medicare/features/perfil/data/perfil_repository.dart';
import 'package:medicare/features/perfil/presentation/providers/perfil_provider.dart';

/// RF-11 — guardar el perfil del médico **y** sus especialidades.
///
/// Son dos rutas del backend: `POST/PATCH /doctors` no acepta especialidades,
/// y `PUT /doctors/{id}/especialidades` es aparte. Lo que se prueba acá es el
/// encadenado, que es donde están los dos errores posibles: mandar el id
/// equivocado, y tragarse el fallo de la segunda llamada.
class _ApiFalsa extends PerfilApi {
  _ApiFalsa({this.errorEspecialidades, this.errorPerfil}) : super(Dio());

  final DioException? errorEspecialidades;
  final DioException? errorPerfil;

  /// Con qué id se llamó a la segunda ruta. `null` si no se llamó.
  int? idRecibido;
  List<int>? especialidadesRecibidas;
  bool creoPerfil = false;

  static DioException httpError(int status) {
    final o = RequestOptions(path: '/doctors');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  /// El id que asigna el servidor al crear. **Distinto** del que se manda,
  /// que es `null`: si el código usara el de entrada en vez del de la
  /// respuesta, la segunda llamada iría a la ruta equivocada y esta prueba
  /// tiene que verlo.
  static const idAsignado = 42;

  static const _medico = MedicoDto(
    idMedico: idAsignado,
    idUsuario: 7,
    nombres: 'Mildred',
    apellidos: 'Lozada',
    numExequatur: '2564588',
    estadoVerificacion: 'PENDIENTE',
  );

  @override
  Future<MedicoDto> crearPerfilMedico(CrearMedicoDto body) async {
    creoPerfil = true;
    if (errorPerfil != null) throw errorPerfil!;
    return _medico;
  }

  @override
  Future<MedicoDto> actualizarPerfilMedico(
    int idMedico,
    ActualizarMedicoDto body,
  ) async {
    if (errorPerfil != null) throw errorPerfil!;
    // Devuelve **el mismo id** que se pidió, como hace el servidor. La
    // primera versión de este doble devolvía siempre 42 y la prueba de
    // edición falló contra su propio andamiaje, no contra el código.
    return _medico.copyWith(idMedico: idMedico);
  }

  @override
  Future<MedicoDto> vincularEspecialidades(
    int idMedico,
    List<int> especialidadIds,
  ) async {
    idRecibido = idMedico;
    especialidadesRecibidas = especialidadIds;
    if (errorEspecialidades != null) throw errorEspecialidades!;
    return _medico;
  }
}

/// Monta el notifier con la API doblada.
({ProviderContainer contenedor, _ApiFalsa api}) armar({
  DioException? errorEspecialidades,
  DioException? errorPerfil,
}) {
  final api = _ApiFalsa(
    errorEspecialidades: errorEspecialidades,
    errorPerfil: errorPerfil,
  );
  final contenedor = ProviderContainer(
    overrides: [
      perfilRepositoryProvider.overrideWithValue(PerfilRepository(api)),
    ],
  );
  addTearDown(contenedor.dispose);
  return (contenedor: contenedor, api: api);
}

Future<Object?> guardar(
  ProviderContainer c, {
  int? idMedico,
  List<int>? especialidades,
}) => c
    .read(edicionPerfilProvider.notifier)
    .guardarMedico(
      idMedico: idMedico,
      nombres: 'Mildred',
      apellidos: 'Lozada',
      numExequatur: '2564588',
      especialidadIds: especialidades,
    );

void main() {
  group('al crear', () {
    test('las especialidades van con el id que devolvió el servidor', () async {
      final (:contenedor, :api) = armar();

      final fallo = await guardar(contenedor, especialidades: [1, 4]);

      expect(fallo, isNull);
      expect(api.creoPerfil, isTrue);
      // El id no existía antes de crear: tiene que salir de la respuesta.
      expect(api.idRecibido, _ApiFalsa.idAsignado);
      expect(api.especialidadesRecibidas, [1, 4]);
    });

    test('sin especialidades no se llama a la segunda ruta', () async {
      // `null` es "no las toques", distinto de `[]` que es "quítalas todas".
      final (:contenedor, :api) = armar();

      await guardar(contenedor);

      expect(api.creoPerfil, isTrue);
      expect(api.idRecibido, isNull);
    });

    test('una lista vacía sí viaja: es quitarlas todas', () async {
      final (:contenedor, :api) = armar();

      await guardar(contenedor, especialidades: []);

      expect(api.especialidadesRecibidas, isEmpty);
    });
  });

  group('al editar', () {
    test('usa el id que ya se tenía', () async {
      final (:contenedor, :api) = armar();

      await guardar(contenedor, idMedico: 5, especialidades: [2]);

      expect(api.creoPerfil, isFalse);
      expect(api.idRecibido, 5);
    });
  });

  group('cuando falla', () {
    test('si falla el perfil, no se intentan las especialidades', () async {
      // Sin id de médico no hay a qué vincularlas: intentarlo daría un 404
      // que confundiría el diagnóstico.
      final (:contenedor, :api) = armar(errorPerfil: _ApiFalsa.httpError(409));

      final fallo = await guardar(contenedor, especialidades: [1]);

      expect(fallo, isNotNull);
      expect(api.idRecibido, isNull);
    });

    test('si fallan las especialidades, el perfil queda guardado', () async {
      // No hay transacción entre dos rutas HTTP. El mensaje tiene que decir
      // qué se guardó y qué no: un "algo salió mal" haría reescribir todo el
      // formulario para nada.
      final (:contenedor, :api) = armar(
        errorEspecialidades: _ApiFalsa.httpError(500),
      );

      final fallo = await guardar(contenedor, especialidades: [1]);

      expect(api.creoPerfil, isTrue, reason: 'el perfil sí se guardó');
      expect(fallo, isNotNull);
      expect(
        '$fallo',
        contains('perfil'),
        reason: 'el mensaje tiene que distinguir las dos mitades',
      );
    });
  });
}
