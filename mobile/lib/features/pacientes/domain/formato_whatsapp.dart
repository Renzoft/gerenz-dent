/// Validación y formato de números de WhatsApp en el teléfono.
///
/// La validación definitiva la hace la API; aquí solo se da aviso inmediato
/// con las mismas reglas (celular peruano de 9 dígitos o número con +código).
abstract final class FormatoWhatsapp {
  static final _separadores = RegExp(r'[\s\-().]');
  static final _soloDigitos = RegExp(r'^\d+$');
  static final _celularPeru = RegExp(r'^9\d{8}$');

  /// Devuelve el mensaje de error, o `null` si el número es válido.
  static String? validar(String? entrada) {
    final texto = (entrada ?? '').trim();
    if (texto.isEmpty) return 'Ingresa el número de WhatsApp';

    var limpio = texto.replaceAll(_separadores, '');
    var internacional = false;
    if (limpio.startsWith('+')) {
      limpio = limpio.substring(1);
      internacional = true;
    } else if (limpio.startsWith('00')) {
      limpio = limpio.substring(2);
      internacional = true;
    }
    if (!_soloDigitos.hasMatch(limpio)) {
      return 'Solo dígitos, espacios o guiones';
    }
    if (!internacional) {
      if (_celularPeru.hasMatch(limpio)) return null;
      if (limpio.length == 11 && limpio.startsWith('519')) return null;
      return 'Celular de 9 dígitos que empiece con 9';
    }
    if (limpio.startsWith('51') &&
        !_celularPeru.hasMatch(limpio.substring(2))) {
      return 'Celular de 9 dígitos que empiece con 9';
    }
    if (limpio.startsWith('0') || limpio.length < 8 || limpio.length > 15) {
      return 'Número internacional no válido';
    }
    return null;
  }

  /// "+51987654321" → "+51 987 654 321". Otros países se muestran tal cual.
  static String mostrar(String e164) {
    if (e164.startsWith('+51') && e164.length == 12) {
      final n = e164.substring(3);
      return '+51 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
    }
    return e164;
  }
}
