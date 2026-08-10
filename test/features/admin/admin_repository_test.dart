import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/data/medico_dto.dart';
import 'package:medicare/core/domain/medico.dart';
import 'package:medicare/core/domain/pagina.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/features/admin/data/admin_api.dart';
import 'package:medicare/features/admin/data/admin_dto.dart';
import 'package:medicare/features/admin/data/admin_repository.dart';

class _ApiFalsa extends AdminApi {
  _ApiFalsa({
    this.errorPendientes,
    this.errorVerificacion,
    this.total = 1,
    this.estado = 'PENDIENTE',
  }) : super(Dio());

  final DioException? errorPendientes;
  final DioException? errorVerificacion;
  final int total;
  final String estado;

  int? paginaPedida;
  int? limitePedido;
  int? idMedicoActualizado;
  String? estadoPedido;

  @override
  Future<PaginaMedicosAdminDto> pendientes({
    int pagina = 1,
    int limite = Pagina.limiteDefecto,
  }) async {
    paginaPedida = pagina;
    limitePedido = limite;
    if (errorPendientes != null) throw errorPendientes!;

    return PaginaMedicosAdminDto(
      data: [
        MedicoDto(
          idMedico: pagina,
          idUsuario: 200 + pagina,
          nombres: 'Carlos',
          apellidos: 'Ramírez',
          numExequatur: 'EXQ-$pagina',
          estadoVerificacion: estado,
        ),
      ],
      total: total,
      page: pagina,
      limit: limite,
    );
  }

  @override
  Future<MedicoDto> actualizarVerificacion({
    required int idMedico,
    required String estado,
  }) async {
    idMedicoActualizado = idMedico;
    estadoPedido = estado;
    if (errorVerificacion != null) throw errorVerificacion!;

    return MedicoDto(
      idMedico: idMedico,
      idUsuario: 200 + idMedico,
      nombres: 'Carlos',
      apellidos: 'Ramírez',
      numExequatur: 'EXQ-$idMedico',
      estadoVerificacion: estado,
    );
  }
}

void main() {
  group('pendientes — RF-11', () {
    test('camino feliz: traduce y arma la página', () async {
      final r = await AdminRepository(_ApiFalsa(total: 2)).pendientes();

      final p = r.valorONull!;
      expect(p.items.single.nombreCompleto, 'Dr. Carlos Ramírez');
      expect(p.items.single.estadoVerificacion, EstadoVerificacion.pendiente);
      expect(p.total, 2);
    });

    test('pide la página que se le pasa', () async {
      final api = _ApiFalsa();
      await AdminRepository(api).pendientes(pagina: 2);
      expect(api.paginaPedida, 2);
    });

    test('camino de error: sin conexión', () async {
      final r = await AdminRepository(
        _ApiFalsa(
          errorPendientes: DioException(
            requestOptions: RequestOptions(path: '/doctors'),
            type: DioExceptionType.connectionError,
          ),
        ),
      ).pendientes();

      expect(r.failureONull, isA<SinConexion>());
    });
  });

  group('verificar / rechazar — RF-11', () {
    test('verificar manda VERIFICADO y traduce la respuesta', () async {
      final api = _ApiFalsa(estado: 'VERIFICADO');
      final r = await AdminRepository(api).verificar(7);

      expect(api.idMedicoActualizado, 7);
      expect(api.estadoPedido, 'VERIFICADO');
      expect(r.valorONull!.estadoVerificacion, EstadoVerificacion.verificado);
    });

    test('rechazar manda RECHAZADO', () async {
      final api = _ApiFalsa(estado: 'RECHAZADO');
      await AdminRepository(api).rechazar(7);

      expect(api.estadoPedido, 'RECHAZADO');
    });

    test('camino de error: el backend rechaza (403 - no es admin)', () async {
      final r = await AdminRepository(
        _ApiFalsa(
          errorVerificacion: DioException(
            requestOptions: RequestOptions(path: '/doctors/7/verificacion'),
            response: Response(
              requestOptions: RequestOptions(path: '/doctors/7/verificacion'),
              statusCode: 403,
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      ).verificar(7);

      expect(r.failureONull, isA<Prohibido>());
    });
  });
}
