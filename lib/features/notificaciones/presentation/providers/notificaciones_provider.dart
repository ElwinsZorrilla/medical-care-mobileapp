import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data/notificaciones_provider.dart';
import '../../../../core/domain/notificacion.dart';
import '../../../../core/domain/pagina.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/result.dart';

part 'notificaciones_provider.g.dart';

/// Lo cargado, mas el error de la **pagina siguiente** si lo hubo.
///
/// Son dos cosas distintas: que falle la pagina 3 no debe borrar las dos que
/// el usuario esta leyendo. Es el mismo patron que el listado de medicos.
class BandejaState {
  const BandejaState({required this.pagina, this.errorAlPaginar});

  final Pagina<Notificacion> pagina;
  final Failure? errorAlPaginar;

  /// Cuantas de **las cargadas** estan sin leer. No es el total del servidor:
  /// para eso esta `sinLeerProvider`, que es lo que pinta el badge.
  int get sinLeer => pagina.items.where((n) => !n.leida).length;

  /// `errorAlPaginar` se conserva salvo que se pida limpiarlo con [sinError].
  ///
  /// Antes se borraba en cada `copiar()`, asi que marcar una notificacion como
  /// leida hacia desaparecer el mensaje y el boton del pie —y, como `hayMas`
  /// seguia en true, en su lugar quedaba un skeleton que no cargaba nada.
  BandejaState copiar({
    Pagina<Notificacion>? pagina,
    Failure? errorAlPaginar,
  }) => BandejaState(
    pagina: pagina ?? this.pagina,
    errorAlPaginar: errorAlPaginar ?? this.errorAlPaginar,
  );

  BandejaState sinError({Pagina<Notificacion>? pagina}) =>
      BandejaState(pagina: pagina ?? this.pagina);
}

/// Bandeja de notificaciones — RF-28, RF-29, RF-30.
@riverpod
class Bandeja extends _$Bandeja {
  bool _cargandoMas = false;

  @override
  Future<BandejaState> build() async => BandejaState(pagina: await _pedir(1));

  /// Carga la pagina siguiente y la concatena.
  ///
  /// Se frena si ya hay un error de paginacion: el listener del scroll dispara
  /// en cada rebote y el usuario que ve el error esta, por definicion, al
  /// final de la lista. Sin este freno cada rebote lanzaba otra peticion
  /// —cinco rebotes, cinco viajes— y competia con el boton de reintentar que
  /// se acababa de pintar.
  Future<void> cargarMas() async {
    final actual = state.value;
    if (actual == null ||
        !actual.pagina.hayMas ||
        _cargandoMas ||
        actual.errorAlPaginar != null) {
      return;
    }

    _cargandoMas = true;
    try {
      final siguiente = await _pedir(actual.pagina.siguientePagina);
      state = AsyncData(
        BandejaState(pagina: actual.pagina.concatenar(siguiente)),
      );
    } on Failure catch (e) {
      // Se conserva la lista y se anota el error: el usuario no pierde lo que
      // estaba leyendo y puede reintentar desde el pie.
      state = AsyncData(actual.copiar(errorAlPaginar: e));
    } finally {
      _cargandoMas = false;
    }
  }

  /// Reintenta solo la pagina que fallo, sin recargar todo.
  Future<void> reintentarPagina() async {
    final actual = state.value;
    if (actual?.errorAlPaginar == null) return;
    state = AsyncData(actual!.sinError());
    await cargarMas();
  }

  /// RF-30 — marcar una como leida.
  ///
  /// Optimista: la lista se actualiza al instante y se revierte si el servidor
  /// dice que no. Esperar la respuesta para tachar una notificacion hace que
  /// tocarla se sienta rota con datos moviles lentos.
  ///
  /// La reversion toca **solo esa notificacion**, no restaura la instantanea
  /// entera: marcar dos seguidas y que fallara la primera destachaba tambien
  /// la segunda, que el servidor si habia aceptado. Con red lenta —el mismo
  /// escenario que justifica el optimismo— tocar dos seguidas es lo normal.
  Future<Failure?> marcarLeida(int id) async {
    final antes = state.value;
    if (antes == null) return null;

    final eraLeida = antes.pagina.items
        .where((n) => n.id == id)
        .map((n) => n.leida)
        .firstOrNull;
    if (eraLeida == null) return null;

    state = AsyncData(
      antes.copiar(pagina: _con(antes.pagina, id, leida: true)),
    );

    final r = await ref.read(notificacionesRepositoryProvider).marcarLeida(id);
    if (r.esOk) {
      ref.invalidate(sinLeerProvider);
      return null;
    }

    // Sobre el estado **actual**, no sobre el capturado al entrar.
    final ahora = state.value;
    if (ahora != null) {
      state = AsyncData(
        ahora.copiar(pagina: _con(ahora.pagina, id, leida: eraLeida)),
      );
    }
    return r.failureONull;
  }

  /// RF-30 — marcar todas, en una sola peticion.
  Future<Failure?> marcarTodasLeidas() async {
    final r = await ref
        .read(notificacionesRepositoryProvider)
        .marcarTodasLeidas();
    if (r.esOk) {
      ref
        ..invalidateSelf()
        ..invalidate(sinLeerProvider);
      return null;
    }
    return r.failureONull;
  }

  Pagina<Notificacion> _con(
    Pagina<Notificacion> p,
    int id, {
    required bool leida,
  }) => Pagina(
    items: [
      for (final n in p.items)
        if (n.id == id)
          Notificacion(
            id: n.id,
            tipo: n.tipo,
            titulo: n.titulo,
            cuerpo: n.cuerpo,
            leida: leida,
            enviadaUtc: n.enviadaUtc,
            idCita: n.idCita,
          )
        else
          n,
    ],
    total: p.total,
    pagina: p.pagina,
    limite: p.limite,
  );

  Future<Pagina<Notificacion>> _pedir(int pagina) async {
    final r = await ref
        .read(notificacionesRepositoryProvider)
        .bandeja(pagina: pagina);
    return switch (r) {
      Ok(:final valor) => valor,
      Fallo(:final failure) => throw failure,
    };
  }
}
