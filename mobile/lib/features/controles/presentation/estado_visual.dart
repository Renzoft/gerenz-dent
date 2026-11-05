import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../domain/control.dart';

/// Cómo se ve cada estado de un control: tono + ícono + texto.
///
/// | Estado      | Tono     | Ícono                 |
/// |-------------|----------|-----------------------|
/// | Por recordar| neutro   | schedule              |
/// | Recordado   | marca    | mark_chat_read        |
/// | Confirmó    | éxito    | thumb_up              |
/// | Asistió     | éxito    | check_circle          |
/// | No vino     | peligro  | person_off            |
/// | Cancelado   | neutro   | block                 |
/// | Vencido     | aviso    | event_busy            |
ChipEstado chipDeControl(Control c) {
  if (c.vencido && c.esAbierto) {
    return const ChipEstado(
      tono: Tono.aviso,
      icono: Icons.event_busy_outlined,
      texto: 'Vencido',
    );
  }
  return switch (c.estado) {
    EstadoControl.pendiente => const ChipEstado(
      tono: Tono.neutro,
      icono: Icons.schedule,
      texto: 'Por recordar',
    ),
    EstadoControl.recordado => const ChipEstado(
      tono: Tono.marca,
      icono: Icons.mark_chat_read_outlined,
      texto: 'Recordado',
    ),
    EstadoControl.confirmado => const ChipEstado(
      tono: Tono.exito,
      icono: Icons.thumb_up_alt_outlined,
      texto: 'Confirmó',
    ),
    EstadoControl.asistio => const ChipEstado(
      tono: Tono.exito,
      icono: Icons.check_circle_outline,
      texto: 'Asistió',
    ),
    EstadoControl.noAsistio => const ChipEstado(
      tono: Tono.peligro,
      icono: Icons.person_off_outlined,
      texto: 'No vino',
    ),
    EstadoControl.cancelado => const ChipEstado(
      tono: Tono.neutro,
      icono: Icons.block,
      texto: 'Cancelado',
    ),
  };
}
