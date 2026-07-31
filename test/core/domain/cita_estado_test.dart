import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare/core/domain/cita_estado.dart';

void main() {
  group('CitaEstado.fromApi', () {
    test('mapea los cinco valores reales del backend', () {
      // Strings verificados en F00 contra el enum de cita.entity.ts.
      expect(CitaEstado.fromApi('PENDIENTE'), CitaEstado.pendiente);
      expect(CitaEstado.fromApi('CONFIRMADA'), CitaEstado.confirmada);
      expect(CitaEstado.fromApi('CANCELADA'), CitaEstado.cancelada);
      expect(CitaEstado.fromApi('COMPLETADA'), CitaEstado.completada);
      expect(CitaEstado.fromApi('NO_ASISTIO'), CitaEstado.noAsistio);
    });

    test('falla ruidoso ante un estado desconocido', () {
      // Camino de error. Un estado nuevo del lado servidor tiene que romper
      // acá y no colarse como default silencioso: una cita cancelada
      // pintada como pendiente hace que alguien se presente a una consulta
      // que no existe.
      expect(
        () => CitaEstado.fromApi('REPROGRAMADA'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('el mensaje de error nombra los valores esperados', () {
      expect(
        () => CitaEstado.fromApi('X'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('NO_ASISTIO'),
          ),
        ),
      );
    });

    test('es sensible a mayúsculas: el backend manda MAYÚSCULAS', () {
      expect(
        () => CitaEstado.fromApi('pendiente'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ida y vuelta por apiValue', () {
      for (final estado in CitaEstado.values) {
        expect(CitaEstado.fromApi(estado.apiValue), estado);
      }
    });
  });

  group('semántica visual', () {
    test('cada estado tiene glifo propio: el color nunca comunica solo', () {
      final glifos = CitaEstado.values.map((e) => e.glifo).toSet();
      expect(glifos.length, CitaEstado.values.length);
    });

    test('cada estado tiene etiqueta no vacía', () {
      for (final estado in CitaEstado.values) {
        expect(estado.etiqueta, isNotEmpty);
      }
    });

    test('el color cambia entre tema claro y oscuro', () {
      for (final estado in CitaEstado.values) {
        expect(
          estado.color(Brightness.light),
          isNot(estado.color(Brightness.dark)),
          reason: '${estado.name} debe adaptarse al brillo',
        );
      }
    });

    test('no asistió es el granate atenuado, un grado bajo cancelada', () {
      final cancelada = CitaEstado.cancelada.color(Brightness.light);
      final noAsistio = CitaEstado.noAsistio.color(Brightness.light);
      expect(noAsistio.r, closeTo(cancelada.r, 0.001));
      expect(noAsistio.a, lessThan(cancelada.a));
    });
  });

  group('esTerminal', () {
    test('cancelada, completada y no asistió cierran la cita', () {
      expect(CitaEstado.cancelada.esTerminal, isTrue);
      expect(CitaEstado.completada.esTerminal, isTrue);
      expect(CitaEstado.noAsistio.esTerminal, isTrue);
    });

    test('pendiente y confirmada siguen abiertas', () {
      expect(CitaEstado.pendiente.esTerminal, isFalse);
      expect(CitaEstado.confirmada.esTerminal, isFalse);
    });
  });
}
