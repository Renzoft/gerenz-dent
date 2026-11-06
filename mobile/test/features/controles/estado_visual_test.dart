import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/controles/presentation/estado_visual.dart';

import '../../helpers/fakes.dart';

void main() {
  final hoy = DateTime(2026, 11, 6);

  String texto(Control c) => chipDeControl(c, hoy: hoy).texto;

  test(
    'un control de hoy que nunca se recordó dice "Hoy", no "Por recordar"',
    () {
      expect(texto(controlPrueba(fecha: hoy)), 'Hoy');
    },
  );

  test('uno de mañana o de más adelante sigue "Por recordar"', () {
    expect(texto(controlPrueba(fecha: DateTime(2026, 11, 7))), 'Por recordar');
    expect(texto(controlPrueba(fecha: DateTime(2026, 11, 20))), 'Por recordar');
  });

  test(
    'si ya se recordó o confirmó, se mantiene ese estado aunque sea hoy',
    () {
      expect(
        texto(controlPrueba(fecha: hoy, estado: EstadoControl.recordado)),
        'Recordado',
      );
      expect(
        texto(controlPrueba(fecha: hoy, estado: EstadoControl.confirmado)),
        'Confirmó',
      );
    },
  );

  test('los cerrados y los vencidos no cambian', () {
    expect(
      texto(controlPrueba(fecha: hoy, estado: EstadoControl.asistio)),
      'Asistió',
    );
    expect(
      texto(controlPrueba(fecha: hoy, estado: EstadoControl.noAsistio)),
      'No vino',
    );
    expect(
      texto(
        controlPrueba(
          fecha: DateTime(2026, 11, 4),
          vencido: true,
          diasAtraso: 2,
        ),
      ),
      'Vencido',
    );
  });
}
