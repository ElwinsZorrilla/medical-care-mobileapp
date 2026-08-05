import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/domain/medico.dart';
import 'package:medicare/core/domain/pagina.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/features/busqueda/data/busqueda_api.dart';
import 'package:medicare/features/busqueda/data/busqueda_dto.dart';
import 'package:medicare/features/busqueda/data/busqueda_repository.dart';

class _ApiFalsa extends BusquedaApi {
  _ApiFalsa({this.error, this.total = 3, this.estado = 'VERIFICADO'})
    : super(Dio());

  final DioException? error;
  final int total;
  final String estado;

  int? especialidadPedida;
  int? paginaPedida;
  int? limitePedido;

  @override
  Future<PaginaMedicosDto> medicos({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
    int? especialidadId,
  }) async {
    paginaPedida = pagina;
    limitePedido = limite;
    especialidadPedida = especialidadId;
    if (error != null) throw error!;

    return PaginaMedicosDto(
      data: [
        MedicoDto(
          idMedico: pagina,
          idUsuario: 100 + pagina,
          nombres: 'Ana',
          apellidos: 'Gómez',
          numExequatur: 'EXQ-$pagina',
          estadoVerificacion: estado,
          especialidades: const [
            EspecialidadDto(idEspecialidad: 4, nombre: 'Cardiología'),
          ],
          tarifaConsulta: 1500,
        ),
      ],
      total: total,
      page: pagina,
      limit: limite,
    );
  }
}

void main() {
  group('médicos — RF-13, RF-14, RF-15', () {
    test('camino feliz: traduce y arma la página', () async {
      final r = await BusquedaRepository(_ApiFalsa(total: 3)).medicos();

      final p = r.valorONull!;
      expect(p.items.single.nombreCompleto, 'Dr. Ana Gómez');
      expect(p.total, 3);
      expect(p.pagina, 1);
    });

    test('RF-13: la especialidad del médico viaja con él', () async {
      final r = await BusquedaRepository(_ApiFalsa()).medicos();
      expect(r.valorONull!.items.single.especialidadesTexto, 'Cardiología');
    });

    test('RF-14: pasa el filtro de especialidad', () async {
      final api = _ApiFalsa();
      await BusquedaRepository(api).medicos(especialidadId: 4);
      expect(api.especialidadPedida, 4);
    });

    test('sin filtro no manda el parámetro', () async {
      final api = _ApiFalsa();
      await BusquedaRepository(api).medicos();
      expect(api.especialidadPedida, isNull);
    });

    test('RF-15: pide la página que se le pasa', () async {
      final api = _ApiFalsa();
      await BusquedaRepository(api).medicos(pagina: 3);
      expect(api.paginaPedida, 3);
    });

    test('camino de error: sin conexión', () async {
      final r = await BusquedaRepository(
        _ApiFalsa(
          error: DioException(
            requestOptions: RequestOptions(path: '/doctors'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).medicos();

      expect(r.failureONull, isA<SinConexion>());
    });

    test('camino de error: un estado desconocido falla ruidoso', () async {
      // Si un solo médico de la lista trae un estado que la app no mapea,
      // es preferible fallar a pintar la lista con un badge equivocado.
      final r = await BusquedaRepository(
        _ApiFalsa(estado: 'EN_TRAMITE'),
      ).medicos();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorInesperado>());
    });
  });

  group('recorte del límite', () {
    test('no deja pedir más de lo que el backend acepta', () async {
      // `limit=999` devuelve 400 por @Max(50). El recorte pasa por la API.
      final api = _ApiFalsa();
      await BusquedaRepository(api).medicos(limite: 999);
      expect(api.limitePedido, Pagina.limiteMaximo);
    });
  });

  group('PerfilMedico compartido', () {
    test('especialidadesTexto tolera un médico sin especialidades', () {
      const m = PerfilMedico(
        idMedico: 1,
        idUsuario: 1,
        nombres: 'A',
        apellidos: 'B',
        numExequatur: 'X',
        estadoVerificacion: EstadoVerificacion.pendiente,
      );
      expect(m.especialidadesTexto, 'Sin especialidades');
    });
  });
}
