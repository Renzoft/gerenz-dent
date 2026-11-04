import 'package:intl/intl.dart';

/// Montos en soles: "S/ 1,300.00" (formato peruano: coma para miles, punto
/// para decimales). La API calcula con decimales exactos; aquí solo se muestra.
abstract final class Moneda {
  static final _formato = NumberFormat.currency(
    locale: 'en_US', // separadores iguales a los de Perú
    symbol: 'S/ ',
    decimalDigits: 2,
  );

  static String formatear(num monto) => _formato.format(monto);

  /// Interpreta lo que escribe el doctor: "150", "150.5", "1,300.50", "150,50".
  /// Devuelve `null` si no es un número válido.
  static double? leer(String? texto) {
    var t = (texto ?? '').trim().replaceAll('S/', '').replaceAll(' ', '');
    if (t.isEmpty) return null;
    final ultimaComa = t.lastIndexOf(',');
    final ultimoPunto = t.lastIndexOf('.');
    if (ultimaComa > ultimoPunto && t.length - ultimaComa <= 3) {
      // "150,50": la coma es el separador decimal.
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
    final valor = double.tryParse(t);
    if (valor == null || valor.isNaN || valor.isInfinite) return null;
    return (valor * 100).roundToDouble() / 100;
  }
}
