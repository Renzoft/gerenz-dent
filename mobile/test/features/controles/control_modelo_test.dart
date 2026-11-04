import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';

void main() {
  test('lee un control de la API con su paciente', () {
    final c = Control.fromJson({
      'id': 'c-1',
      'planId': 'pl-1',
      'pacienteId': 'p-1',
      'fecha': '2026-11-11',
      'hora': '19:30:00',
      'nota': 'Cambio de ligas',
      'estado': 'CONFIRMADO',
      'abierto': true,
      'vencido': false,
      'diasAtraso': 0,
      'tratamiento': {'id': 't-1', 'nombre': 'Brackets (ortodoncia)'},
      'piezas': null,
      'paciente': {
        'id': 'p-1',
        'nombre': 'Juan Pérez',
        'whatsapp': '+51987654321',
        'consienteWhatsapp': true,
      },
    });

    expect(c.fecha, DateTime(2026, 11, 11));
    expect(c.hora, const TimeOfDay(hour: 19, minute: 30));
    expect(c.estado, EstadoControl.confirmado);
    expect(c.esAbierto, isTrue);
    expect(c.tratamientoNombre, 'Brackets (ortodoncia)');
    expect(c.paciente!.nombre, 'Juan Pérez');
  });

  test('estados abiertos y cerrados', () {
    expect(EstadoControl.pendiente.esAbierto, isTrue);
    expect(EstadoControl.recordado.esAbierto, isTrue);
    expect(EstadoControl.asistio.esAbierto, isFalse);
    expect(EstadoControl.desdeApi('NO_ASISTIO'), EstadoControl.noAsistio);
  });

  test('el control nuevo solo envía los campos con valor', () {
    final json = NuevoControl(
      pacienteId: 'p-1',
      tratamientoId: 't-1',
      fecha: DateTime(2026, 12, 10),
      nota: '   ',
    ).toJson();

    expect(json, {
      'pacienteId': 'p-1',
      'tratamientoId': 't-1',
      'fecha': '2026-12-10',
    });

    final conTodo = NuevoControl(
      pacienteId: 'p-1',
      tratamientoId: 't-2',
      fecha: DateTime(2026, 12, 10),
      hora: const TimeOfDay(hour: 18, minute: 0),
      nota: ' Traer radiografía ',
      piezas: 2,
    ).toJson();
    expect(conTodo['hora'], '18:00');
    expect(conTodo['nota'], 'Traer radiografía');
    expect(conTodo['piezas'], 2);
  });
}
