import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formatos de fecha y hora en español de Perú (RNF-02).
///
/// Requiere `initializeDateFormatting('es_PE')` (se llama en `main`).
abstract final class Fechas {
  static const _locale = 'es_PE';

  /// Solo la fecha (sin hora) de hoy en el teléfono.
  static DateTime hoy([DateTime? ahora]) =>
      DateUtils.dateOnly(ahora ?? DateTime.now());

  /// "2026-11-10" (formato de la API).
  static String aIso(DateTime fecha) => DateFormat('yyyy-MM-dd').format(fecha);

  /// "mar 11 nov".
  static String corta(DateTime fecha) =>
      _sinPuntos(DateFormat('EEE d MMM', _locale).format(fecha));

  /// "martes 11 de noviembre".
  static String larga(DateTime fecha) =>
      DateFormat("EEEE d 'de' MMMM", _locale).format(fecha);

  /// "Hoy", "Mañana", "Ayer" o "mar 11 nov".
  static String relativa(DateTime fecha, {DateTime? hoy}) {
    final base = hoy ?? Fechas.hoy();
    final dias = DateUtils.dateOnly(fecha).difference(base).inDays;
    return switch (dias) {
      0 => 'Hoy',
      1 => 'Mañana',
      -1 => 'Ayer',
      _ => _capitalizar(corta(fecha)),
    };
  }

  /// "7:30 p. m."
  static String hora(TimeOfDay hora) {
    final h = hora.hourOfPeriod == 0 ? 12 : hora.hourOfPeriod;
    final m = hora.minute.toString().padLeft(2, '0');
    return '$h:$m ${hora.period == DayPeriod.am ? 'a. m.' : 'p. m.'}';
  }

  /// "19:30" o "19:30:00" → TimeOfDay. `null` si viene vacío.
  static TimeOfDay? horaDesdeApi(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    final partes = texto.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  /// TimeOfDay → "19:30" (formato de la API).
  static String horaAApi(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  static String _sinPuntos(String texto) => texto.replaceAll('.', '');

  static String _capitalizar(String texto) =>
      texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
}
