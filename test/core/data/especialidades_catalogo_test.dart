import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/especialidades_catalogo.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/error/failure.dart';

/// Estas pruebas vivían en `busqueda_repository_test.dart`.
///
/// Se mudaron con el catálogo: cuando `perfil` necesitó las especialidades
/// para RF-11, dejaron de ser cosa de un feature. Que `perfil` importara el
/// provider de `busqueda` habría cruzado features (rubro 3.3) y
/// `arquitectura_test.dart` lo habría puesto en rojo.
class _ApiFalsa extends EspecialidadesApi {
  _ApiFalsa({this.error}) : super(Dio());

  final DioException? error;

  static DioException httpError(int status) {
    final o = RequestOptions(path: '/specialties');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(requestOptions: o, statusCode: status),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<List<EspecialidadDto>> catalogo() async {
    if (error != null) throw error!;
    return const [
      EspecialidadDto(idEspecialidad: 1, nombre: 'Medicina General'),
      EspecialidadDto(
        idEspecialidad: 4,
        nombre: 'Cardiología',
        descripcion: 'Corazón',
      ),
    ];
  }
}

void main() {
  group('catálogo de especialidades — RF-11, RF-12', () {
    test('camino feliz: traduce el catálogo', () async {
      final r = await EspecialidadesRepository(_ApiFalsa()).catalogo();

      final lista = r.valorONull!;
      expect(lista, hasLength(2));
      expect(lista.first.nombre, 'Medicina General');
      expect(lista.last.descripcion, 'Corazón');
    });

    test('camino de error: se reporta', () async {
      final r = await EspecialidadesRepository(
        _ApiFalsa(error: _ApiFalsa.httpError(500)),
      ).catalogo();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorServidor>());
    });

    test('una respuesta con la forma equivocada no lanza', () async {
      // El defecto que costó el crash de `tarifaConsulta`: el `Result<T>`
      // promete que ningún camino lanza, y un `TypeError` de parseo se colaba
      // por debajo de esa promesa hasta cerrar la app.
      final api = _ApiRota();

      final r = await EspecialidadesRepository(api).catalogo();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ContratoRoto>());
    });
  });
}

/// Devuelve lo que el backend devolvería si renombrara un campo.
class _ApiRota extends EspecialidadesApi {
  _ApiRota() : super(Dio());

  @override
  Future<List<EspecialidadDto>> catalogo() async =>
      // `idEspecialidad` como cadena: exactamente la clase de deriva que
      // tumbó la app con la tarifa.
      [
        EspecialidadDto.fromJson(const {'idEspecialidad': '1', 'nombre': 'X'}),
      ];
}
