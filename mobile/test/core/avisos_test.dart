import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/avisos/avisos_diarios.dart';

void main() {
  const cincoYMedia = TimeOfDay(hour: 17, minute: 30);

  test('antes de la hora, el de hoy se personaliza con la cantidad', () {
    final avisos = planificarAvisos(
      ahora: DateTime(2026, 11, 10, 9, 0),
      hora: cincoYMedia,
      pendientesHoy: 3,
    );

    expect(avisos, hasLength(14));
    expect(avisos.first.cuando, DateTime(2026, 11, 10, 17, 30));
    expect(
      avisos.first.texto,
      'Mañana tienes 3 pacientes por recordar. Toca para enviar los mensajes.',
    );
    expect(avisos[1].cuando, DateTime(2026, 11, 11, 17, 30));
    expect(avisos[1].texto, 'Revisa a quién recordarle su cita de mañana.');
  });

  test('en singular cuando es un paciente', () {
    final avisos = planificarAvisos(
      ahora: DateTime(2026, 11, 10, 9, 0),
      hora: cincoYMedia,
      pendientesHoy: 1,
    );
    expect(avisos.first.texto, startsWith('Mañana tienes 1 paciente por'));
  });

  test('si hoy no hay nada por enviar, hoy no se avisa', () {
    final avisos = planificarAvisos(
      ahora: DateTime(2026, 11, 10, 9, 0),
      hora: cincoYMedia,
      pendientesHoy: 0,
    );

    expect(avisos, hasLength(13));
    expect(avisos.first.cuando, DateTime(2026, 11, 11, 17, 30));
  });

  test('si ya pasó la hora, empieza mañana', () {
    final avisos = planificarAvisos(
      ahora: DateTime(2026, 11, 10, 18, 0),
      hora: cincoYMedia,
      pendientesHoy: 2,
    );

    expect(avisos.first.cuando, DateTime(2026, 11, 11, 17, 30));
    expect(avisos.first.texto, 'Revisa a quién recordarle su cita de mañana.');
  });

  test('cruza el fin de mes y no repite ids', () {
    final avisos = planificarAvisos(
      ahora: DateTime(2026, 11, 25, 9, 0),
      hora: cincoYMedia,
    );

    expect(avisos.last.cuando, DateTime(2026, 12, 8, 17, 30));
    expect(avisos.map((a) => a.id).toSet(), hasLength(avisos.length));
  });
}
