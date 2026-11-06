import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/controles/presentation/tarjeta_control.dart';

import '../../helpers/fakes.dart';

void main() {
  final d = DateTime(2026, 11, 6);

  Control c(String id, String plan, int dia, EstadoControl estado) =>
      controlPrueba(
        id: id,
        planId: plan,
        fecha: d.add(Duration(days: dia)),
        estado: estado,
      );

  List<String> ids(List<Control> l) => l.map((x) => x.id).toList();

  test('un "No vino" sin nada después queda pendiente de fecha', () {
    expect(ids(sinFechaNueva([c('a', 'p1', -3, EstadoControl.noAsistio)])), [
      'a',
    ]);
  });

  test('si ya tiene un control abierto o uno posterior, no', () {
    expect(
      sinFechaNueva([
        c('a', 'p1', -3, EstadoControl.noAsistio),
        c('b', 'p1', 4, EstadoControl.pendiente),
      ]),
      isEmpty,
    );
    expect(
      sinFechaNueva([
        c('a', 'p1', -9, EstadoControl.noAsistio),
        c('b', 'p1', -2, EstadoControl.asistio),
      ]),
      isEmpty,
    );
  });

  test('se mira cada tratamiento por separado', () {
    final r = sinFechaNueva([
      c('a', 'p1', -3, EstadoControl.noAsistio),
      c('b', 'p2', 5, EstadoControl.pendiente),
      c('c', 'p3', -10, EstadoControl.noAsistio),
      c('d', 'p4', -1, EstadoControl.asistio),
    ]);
    expect(ids(r), ['c', 'a']); // el más antiguo primero
  });
}
