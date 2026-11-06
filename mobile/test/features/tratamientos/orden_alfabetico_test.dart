import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:gerenz_dent/features/tratamientos/domain/tratamiento.dart';

Tratamiento t(String nombre, {bool activo = true}) => Tratamiento(
  id: nombre,
  nombre: nombre,
  tipoPrecio: TipoPrecio.fijo,
  activo: activo,
);

List<String> nombres(List<Tratamiento> lista) =>
    lista.map((x) => x.nombre).toList();

void main() {
  test('de la A a la Z, sin que importen tildes ni mayúsculas', () {
    final ordenada = ordenarAlfabeticamente([
      t('Resina'),
      t('Extracción dental'),
      t('aplicación de flúor'),
      t('Ácido fosfórico'),
      t('Brackets (ortodoncia)'),
      t('Endodoncia'),
    ]);

    expect(nombres(ordenada), [
      'Ácido fosfórico',
      'aplicación de flúor',
      'Brackets (ortodoncia)',
      'Endodoncia',
      'Extracción dental',
      'Resina',
    ]);
  });

  test('la ñ va después de la n', () {
    final ordenada = ordenarAlfabeticamente([
      t('Ñandú'),
      t('Oclusión'),
      t('Nz'),
    ]);
    expect(nombres(ordenada), ['Nz', 'Ñandú', 'Oclusión']);
  });

  test(
    'en el catálogo completo, primero los activos (cada grupo de la A a la Z)',
    () {
      final ordenada = ordenarAlfabeticamente([
        t('Zeta', activo: false),
        t('Resina'),
        t('Blanqueamiento', activo: false),
        t('Corona'),
      ], activosPrimero: true);

      expect(nombres(ordenada), ['Corona', 'Resina', 'Blanqueamiento', 'Zeta']);
    },
  );
}
