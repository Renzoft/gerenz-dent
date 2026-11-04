import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/features/pacientes/domain/formato_whatsapp.dart';

void main() {
  group('validar', () {
    for (final valido in [
      '987654321',
      '987 654 321',
      '987-654-321',
      '51987654321',
      '+51 987 654 321',
      '0051987654321',
      '+1 415 555 2671',
    ]) {
      test('acepta "$valido"', () {
        expect(FormatoWhatsapp.validar(valido), isNull);
      });
    }

    for (final invalido in [
      '887654321',
      '98765432',
      '9876543210',
      '+51 1234567',
      '+1234567',
      '987abc321',
    ]) {
      test('rechaza "$invalido"', () {
        expect(FormatoWhatsapp.validar(invalido), isNotNull);
      });
    }

    test('exige el número', () {
      expect(FormatoWhatsapp.validar('  '), 'Ingresa el número de WhatsApp');
      expect(FormatoWhatsapp.validar(null), 'Ingresa el número de WhatsApp');
    });
  });

  group('mostrar', () {
    test('agrupa los celulares peruanos', () {
      expect(FormatoWhatsapp.mostrar('+51987654321'), '+51 987 654 321');
    });

    test('deja igual los de otros países', () {
      expect(FormatoWhatsapp.mostrar('+14155552671'), '+14155552671');
    });
  });
}
