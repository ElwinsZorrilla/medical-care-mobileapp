import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/domain/pagina.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/network/politica_reintento.dart';
import 'package:medicare/features/admin/data/admin_api.dart';
import 'package:medicare/features/admin/data/admin_dto.dart';
import 'package:medicare/features/admin/data/admin_repository.dart';
import 'package:medicare/features/admin/presentation/providers/admin_provider.dart';

/// El efecto secundario de verificar/rechazar: la cola se refresca sola
/// —mismo criterio que `efectos_notificadores_test.dart` en `citas`— y la
/// paginación real de la cola.
class _ApiFalsa extends AdminApi {
  _ApiFalsa({this.totalPaginas = 1, this.falloVerificacion}) : super(Dio());

  final int totalPaginas;
  final DioException? falloVerificacion;
  int peticionesPendientes = 0;

  MedicoDto _medico(int pagina) => MedicoDto(
    idMedico: pagina,
    idUsuario: 300 + pagina,
    nombres: 'Carlos',
    apellidos: 'Ramírez',
    numExequatur: 'EXQ-$pagina',
    estadoVerificacion: 'PENDIENTE',
  );

  @override
  Future<PaginaMedicosAdminDto> pendientes({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) async {
    peticionesPendientes++;
    return PaginaMedicosAdminDto(
      data: [_medico(pagina)],
      total: totalPaginas,
      page: pagina,
      limit: 1,
    );
  }

  @override
  Future<MedicoDto> actualizarVerificacion({
    required int idMedico,
    required String estado,
  }) async {
    if (falloVerificacion != null) throw falloVerificacion!;
    return _medico(idMedico).copyWith(estadoVerificacion: estado);
  }
}

void main() {
  Future<(ProviderContainer, _ApiFalsa)> preparar({
    int totalPaginas = 1,
    DioException? falloVerificacion,
  }) async {
    final api = _ApiFalsa(
      totalPaginas: totalPaginas,
      falloVerificacion: falloVerificacion,
    );
    final c = ProviderContainer(
      retry: PoliticaReintento.decidir,
      overrides: [
        adminRepositoryProvider.overrideWithValue(AdminRepository(api)),
      ],
    );
    addTearDown(c.dispose);
    // Se mantiene vivo para que la invalidación produzca una recarga real.
    c.listen(colaVerificacionProvider, (_, _) {});
    await c.read(colaVerificacionProvider.future);
    return (c, api);
  }

  group('ColaVerificacion.verificar / rechazar — RF-11', () {
    test('al verificar bien, la cola se refresca', () async {
      final (c, api) = await preparar();
      final antes = api.peticionesPendientes;

      final r = await c.read(colaVerificacionProvider.notifier).verificar(1);
      await c.read(colaVerificacionProvider.future);

      expect(r.esOk, isTrue);
      // Sin esto el médico ya resuelto seguiría apareciendo como pendiente.
      expect(api.peticionesPendientes, greaterThan(antes));
    });

    test('al rechazar bien, la cola se refresca', () async {
      final (c, api) = await preparar();
      final antes = api.peticionesPendientes;

      final r = await c.read(colaVerificacionProvider.notifier).rechazar(1);
      await c.read(colaVerificacionProvider.future);

      expect(r.esOk, isTrue);
      expect(api.peticionesPendientes, greaterThan(antes));
    });

    test('si falla, NO se refresca', () async {
      final o = RequestOptions(path: '/doctors/1/verificacion');
      final (c, api) = await preparar(
        falloVerificacion: DioException(
          requestOptions: o,
          response: Response<dynamic>(requestOptions: o, statusCode: 403),
          type: DioExceptionType.badResponse,
        ),
      );
      final antes = api.peticionesPendientes;

      final r = await c.read(colaVerificacionProvider.notifier).verificar(1);

      expect(r.failureONull, isA<Prohibido>());
      expect(api.peticionesPendientes, antes);
    });
  });

  group('ColaVerificacion.cargarMas — paginación real', () {
    test('concatena la página siguiente sin perder la primera', () async {
      final (c, api) = await preparar(totalPaginas: 2);

      await c.read(colaVerificacionProvider.notifier).cargarMas();
      final estado = await c.read(colaVerificacionProvider.future);

      expect(estado.pagina.items, hasLength(2));
      expect(api.peticionesPendientes, 2);
    });

    test('no pide de más cuando ya no hay siguiente página', () async {
      final (c, api) = await preparar();
      final antes = api.peticionesPendientes;

      await c.read(colaVerificacionProvider.notifier).cargarMas();

      expect(api.peticionesPendientes, antes);
    });
  });
}
