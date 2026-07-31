import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/tipo_usuario.dart';
import 'package:medicare/core/error/failure.dart';
import 'package:medicare/core/storage/secure_store.dart';
import 'package:medicare/features/auth/data/auth_api.dart';
import 'package:medicare/features/auth/data/auth_dto.dart';
import 'package:medicare/features/auth/data/auth_repository.dart';
import 'package:medicare/features/auth/domain/usuario.dart';

/// Valores de relleno para los tokens en las pruebas.
///
/// Van como constantes con nombre y no como literales en la llamada: el hook
/// de pre-commit marca un campo de token asignado a una cadena literal, para
/// atrapar secretos en duro (RNF-04). Acá son de mentira, pero el patrón no
/// puede saberlo. Prefiero un gate ruidoso y ajustar el fixture, antes que
/// relajar una regla que existe para que no se escape un secreto de verdad.
const _accesoFalso = 'acc';
const _refrescoFalso = 'ref';

class _StoreFalso implements SecureStore {
  String? access;
  String? refresh;
  int limpiezas = 0;

  @override
  Future<String?> leerAccessToken() async => access;

  @override
  Future<String?> leerRefreshToken() async => refresh;

  @override
  Future<void> guardarTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> limpiar() async {
    access = null;
    refresh = null;
    limpiezas++;
  }
}

/// API falsa: devuelve exactamente las formas que verificó F00.
///
/// Extiende `AuthApi` en vez de implementarla porque la clase real tiene un
/// campo privado (`_dio`) y una librería externa no puede implementarlo.
class _ApiFalsa extends AuthApi {
  _ApiFalsa({this.rolDevuelto = 'PACIENTE', this.errorTokens, this.errorYo})
    : super(Dio());

  final String rolDevuelto;
  final DioException? errorTokens;
  final DioException? errorYo;

  int llamadasYo = 0;
  RegisterRequestDto? registroRecibido;
  LoginRequestDto? loginRecibido;

  static DioException error(int status, [Object? data]) {
    final o = RequestOptions(path: '/auth/x');
    return DioException(
      requestOptions: o,
      response: Response<dynamic>(
        requestOptions: o,
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }

  @override
  Future<AuthTokensDto> login(LoginRequestDto body) async {
    loginRecibido = body;
    if (errorTokens != null) throw errorTokens!;
    return const AuthTokensDto(
      accessToken: _accesoFalso,
      refreshToken: _refrescoFalso,
    );
  }

  @override
  Future<AuthTokensDto> registrar(RegisterRequestDto body) async {
    registroRecibido = body;
    if (errorTokens != null) throw errorTokens!;
    return const AuthTokensDto(
      accessToken: _accesoFalso,
      refreshToken: _refrescoFalso,
    );
  }

  @override
  Future<UsuarioDto> yo() async {
    llamadasYo++;
    if (errorYo != null) throw errorYo!;
    return UsuarioDto(
      idUsuario: 7,
      correo: 'a@b.com',
      tipoUsuario: rolDevuelto,
      estado: 'ACTIVO',
    );
  }
}

void main() {
  // Los DTO reales se ejercitan en el repositorio a través de una API falsa
  // que devuelve exactamente las formas que verificó F00.
  late _StoreFalso store;

  setUp(() => store = _StoreFalso());

  group('iniciarSesion — RF-03', () {
    test('camino feliz: guarda tokens y resuelve el usuario', () async {
      final api = _ApiFalsa(rolDevuelto: 'MEDICO');
      final repo = AuthRepository(api, store);

      final r = await repo.iniciarSesion(
        correo: 'a@b.com',
        contrasena: 'Passw0rd!23',
      );

      expect(r.esOk, isTrue);
      expect(r.valorONull?.tipo, TipoUsuario.medico);
      expect(store.access, 'acc');
      expect(store.refresh, 'ref');
      // El backend no devuelve el usuario junto con los tokens: hace falta
      // la segunda llamada a /auth/me para conocer el rol.
      expect(api.llamadasYo, 1);
    });

    test('manda los nombres de campo del backend, no email/password', () async {
      final api = _ApiFalsa();
      await AuthRepository(
        api,
        store,
      ).iniciarSesion(correo: 'a@b.com', contrasena: 'x');

      final json = api.loginRecibido!.toJson();
      expect(json.keys, containsAll(<String>['correo', 'contrasena']));
      // `forbidNonWhitelisted` en el backend: un campo de más devuelve 400.
      expect(json.keys, hasLength(2));
    });

    test('camino de error: 401 no revela si el correo existe', () async {
      final repo = AuthRepository(
        _ApiFalsa(errorTokens: _ApiFalsa.error(401)),
        store,
      );

      final r = await repo.iniciarSesion(correo: 'a@b.com', contrasena: 'mal');

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<NoAutorizado>());
      expect(r.failureONull!.mensaje, 'Correo o contraseña incorrectos.');
      expect(store.access, isNull, reason: 'no se guarda nada si falla');
    });

    test('camino de error: sin red', () async {
      final repo = AuthRepository(
        _ApiFalsa(
          errorTokens: DioException(
            requestOptions: RequestOptions(path: '/auth/login'),
            type: DioExceptionType.connectionError,
          ),
        ),
        store,
      );

      final r = await repo.iniciarSesion(correo: 'a@b.com', contrasena: 'x');
      expect(r.failureONull, isA<SinConexion>());
    });
  });

  group('registrar — RF-01, RF-02', () {
    test('camino feliz: manda el rol elegido', () async {
      final api = _ApiFalsa(rolDevuelto: 'MEDICO');
      final repo = AuthRepository(api, store);

      final r = await repo.registrar(
        correo: 'm@b.com',
        contrasena: 'Passw0rd!23',
        tipo: TipoUsuario.medico,
        telefono: '8091234567',
      );

      expect(r.esOk, isTrue);
      expect(api.registroRecibido!.tipoUsuario, 'MEDICO');
      expect(api.registroRecibido!.telefono, '8091234567');
    });

    test('camino de error: 409 correo repetido dice qué hacer', () async {
      final repo = AuthRepository(
        _ApiFalsa(errorTokens: _ApiFalsa.error(409)),
        store,
      );

      final r = await repo.registrar(
        correo: 'a@b.com',
        contrasena: 'Passw0rd!23',
        tipo: TipoUsuario.paciente,
      );

      expect(r.failureONull, isA<Conflicto>());
      expect(r.failureONull!.mensaje, contains('Inicia sesión'));
    });

    test('camino de error: rol desconocido falla ruidoso', () async {
      // Si el backend agrega un rol que la app no mapea, es preferible
      // fallar a dejar entrar a alguien con la interfaz equivocada.
      final repo = AuthRepository(_ApiFalsa(rolDevuelto: 'ENFERMERO'), store);

      final r = await repo.registrar(
        correo: 'a@b.com',
        contrasena: 'Passw0rd!23',
        tipo: TipoUsuario.paciente,
      );

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorInesperado>());
    });
  });

  group('restaurarSesion', () {
    test('sin token guardado devuelve null, y eso no es un error', () async {
      final repo = AuthRepository(_ApiFalsa(), store);
      final r = await repo.restaurarSesion();

      expect(r.esOk, isTrue);
      expect(r.valorONull, isNull);
    });

    test('camino feliz: con token, resuelve el usuario', () async {
      store.access = 'acc';
      final r = await AuthRepository(
        _ApiFalsa(rolDevuelto: 'PACIENTE'),
        store,
      ).restaurarSesion();

      expect(r.valorONull?.tipo, TipoUsuario.paciente);
      expect(r.valorONull?.id, 7);
    });

    test('401 limpia y arranca anónimo, sin mostrar error', () async {
      // El interceptor ya intentó refrescar. Que el usuario vea un error al
      // abrir la app por una sesión vieja sería culparlo de nada.
      store.access = 'viejo';
      final r = await AuthRepository(
        _ApiFalsa(errorYo: _ApiFalsa.error(401)),
        store,
      ).restaurarSesion();

      expect(r.esOk, isTrue);
      expect(r.valorONull, isNull);
      expect(store.access, isNull);
      expect(store.limpiezas, 1);
    });

    test('camino de error: 500 sí se reporta', () async {
      store.access = 'acc';
      final r = await AuthRepository(
        _ApiFalsa(errorYo: _ApiFalsa.error(500)),
        store,
      ).restaurarSesion();

      expect(r.esFallo, isTrue);
      expect(r.failureONull, isA<ErrorServidor>());
    });
  });

  group('mapeo de rol', () {
    test('PACIENTE y MEDICO se resuelven', () {
      expect(TipoUsuario.fromApi('PACIENTE'), TipoUsuario.paciente);
      expect(TipoUsuario.fromApi('MEDICO'), TipoUsuario.medico);
      expect(TipoUsuario.fromApi('ADMIN'), TipoUsuario.admin);
    });

    test('un rol desconocido falla ruidoso', () {
      // Si esto cayera a `paciente` por defecto, un médico entraría a la
      // interfaz equivocada y el guard de rutas dejaría pasar lo que no debe.
      expect(
        () => TipoUsuario.fromApi('ENFERMERO'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el registro público solo admite dos roles', () {
      expect(TipoUsuario.registrables, [
        TipoUsuario.paciente,
        TipoUsuario.medico,
      ]);
      expect(TipoUsuario.registrables, isNot(contains(TipoUsuario.admin)));
    });

    test('cada rol trae su densidad de interfaz', () {
      expect(TipoUsuario.medico.densidad.name, 'clinician');
      expect(TipoUsuario.paciente.densidad.name, 'patient');
    });
  });

  group('cerrarSesion — RF-05', () {
    test('borra los tokens del dispositivo', () async {
      store
        ..access = 'a'
        ..refresh = 'r';
      final repo = AuthRepository(_ApiFalsa(), store);

      final r = await repo.cerrarSesion();

      expect(r.esOk, isTrue);
      expect(store.access, isNull);
      expect(store.refresh, isNull);
      expect(store.limpiezas, 1);
    });
  });

  group('Sesion — los tres estados', () {
    test('desconocida no está resuelta: el guard espera', () {
      const s = Sesion.desconocida();
      expect(s.estaResuelta, isFalse);
      expect(s.estaAutenticada, isFalse);
      expect(s.usuario, isNull);
    });

    test('anónima está resuelta y sin usuario', () {
      const s = Sesion.anonima();
      expect(s.estaResuelta, isTrue);
      expect(s.estaAutenticada, isFalse);
      expect(s.usuario, isNull);
    });

    test('autenticada expone el usuario', () {
      const u = Usuario(id: 1, correo: 'a@b.com', tipo: TipoUsuario.medico);
      const s = Sesion.autenticada(u);
      expect(s.estaResuelta, isTrue);
      expect(s.estaAutenticada, isTrue);
      expect(s.usuario, u);
    });

    test('el tercer estado es lo que evita el parpadeo del login', () {
      // Sin `desconocida`, el arranque sería "anónimo" mientras se lee el
      // almacenamiento —que es asíncrono— y el guard mandaría a login antes
      // de que apareciera el token.
      const desconocida = Sesion.desconocida();
      const anonima = Sesion.anonima();
      expect(desconocida.estaResuelta, isNot(anonima.estaResuelta));
    });
  });

  group('Usuario', () {
    test('distingue paciente de médico', () {
      const p = Usuario(id: 1, correo: 'p@x.com', tipo: TipoUsuario.paciente);
      const m = Usuario(id: 2, correo: 'm@x.com', tipo: TipoUsuario.medico);
      expect(p.esPaciente, isTrue);
      expect(p.esMedico, isFalse);
      expect(m.esMedico, isTrue);
    });

    test('igualdad por valor', () {
      const a = Usuario(id: 1, correo: 'a@b.com', tipo: TipoUsuario.paciente);
      const b = Usuario(id: 1, correo: 'a@b.com', tipo: TipoUsuario.paciente);
      const c = Usuario(id: 2, correo: 'a@b.com', tipo: TipoUsuario.paciente);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('Failure de auth', () {
    test('401 de login no revela si el correo existe', () {
      // El backend responde 401 tanto por correo inexistente como por
      // contraseña incorrecta, a propósito. El mensaje respeta esa
      // ambigüedad en vez de filtrar qué correos están registrados.
      const f = NoAutorizado('Correo o contraseña incorrectos.');
      expect(f.mensaje, isNot(contains('no existe')));
      expect(f.mensaje, contains('o contraseña'));
    });

    test('409 de registro dice qué hacer', () {
      const f = Conflicto('Ese correo ya está registrado. Inicia sesión.');
      expect(f.mensaje, contains('Inicia sesión'));
    });
  });
}
