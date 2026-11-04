import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));

  final hoy = DateTime(2026, 11, 10); // martes

  test('fecha corta en español y sin puntos', () {
    expect(Fechas.corta(DateTime(2026, 11, 11)), 'mié 11 nov');
  });

  test('fecha larga', () {
    expect(Fechas.larga(DateTime(2026, 11, 11)), 'miércoles 11 de noviembre');
  });

  test('relativa: hoy, mañana, ayer u otra fecha', () {
    expect(Fechas.relativa(hoy, hoy: hoy), 'Hoy');
    expect(Fechas.relativa(DateTime(2026, 11, 11), hoy: hoy), 'Mañana');
    expect(Fechas.relativa(DateTime(2026, 11, 9), hoy: hoy), 'Ayer');
    expect(Fechas.relativa(DateTime(2026, 11, 20), hoy: hoy), 'Vie 20 nov');
  });

  test('hora con a. m. / p. m.', () {
    expect(Fechas.hora(const TimeOfDay(hour: 19, minute: 30)), '7:30 p. m.');
    expect(Fechas.hora(const TimeOfDay(hour: 0, minute: 5)), '12:05 a. m.');
    expect(Fechas.hora(const TimeOfDay(hour: 12, minute: 0)), '12:00 p. m.');
  });

  test('conversión con la API', () {
    expect(Fechas.aIso(DateTime(2026, 1, 5)), '2026-01-05');
    expect(
      Fechas.horaDesdeApi('19:30:00'),
      const TimeOfDay(hour: 19, minute: 30),
    );
    expect(Fechas.horaDesdeApi(null), isNull);
    expect(Fechas.horaAApi(const TimeOfDay(hour: 8, minute: 5)), '08:05');
  });
}
