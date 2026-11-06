import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../../recordatorios/application/recordatorios_providers.dart';
import '../application/controles_providers.dart';
import '../data/controles_repository.dart';

/// Respuesta a "¿Cuándo vuelve?": la fecha elegida, o sin fecha si eligió
/// "Todavía no sabe".
class EleccionVuelta {
  const EleccionVuelta(this.fecha);

  final DateTime? fecha;
}

enum _Opcion {
  manana('Mañana', 1),
  enUnaSemana('En 1 semana', 7),
  enQuinceDias('En 15 días', 15),
  otraFecha('Otra fecha', null),
  noSabe('Todavía no sabe', null);

  const _Opcion(this.titulo, this.dias);

  final String titulo;
  final int? dias;

  static const conFecha = [manana, enUnaSemana, enQuinceDias];
}

/// Hoja "¿Cuándo vuelve?" (atajos de fecha y calendario). Devuelve `null` si
/// la cierra sin elegir. Con [permitirNoSabe] agrega "Todavía no sabe".
Future<EleccionVuelta?> elegirCuandoVuelve(
  BuildContext context, {
  bool permitirNoSabe = false,
}) async {
  final hoy = Fechas.hoy();
  final eleccion = await mostrarOpciones<_Opcion>(
    context,
    titulo: '¿Cuándo vuelve?',
    opciones: [
      for (final o in _Opcion.conFecha)
        Opcion(
          valor: o,
          icono: Icons.event_available_outlined,
          titulo: o.titulo,
          detalle: Fechas.corta(hoy.add(Duration(days: o.dias!))),
        ),
      const Opcion(
        valor: _Opcion.otraFecha,
        icono: Icons.calendar_month_outlined,
        titulo: 'Otra fecha',
        detalle: 'Elegir en el calendario',
      ),
      if (permitirNoSabe)
        const Opcion(
          valor: _Opcion.noSabe,
          icono: Icons.help_outline,
          titulo: 'Todavía no sabe',
          detalle: 'Queda en "No vinieron" para escribirle',
        ),
    ],
  );
  if (eleccion == null || !context.mounted) return null;
  switch (eleccion) {
    case _Opcion.noSabe:
      return const EleccionVuelta(null);
    case _Opcion.otraFecha:
      final fecha = await showDatePicker(
        context: context,
        initialDate: hoy.add(const Duration(days: 7)),
        firstDate: hoy,
        lastDate: hoy.add(const Duration(days: 730)),
        helpText: '¿Cuándo vuelve?',
      );
      return fecha == null ? null : EleccionVuelta(fecha);
    default:
      return EleccionVuelta(hoy.add(Duration(days: eleccion.dias!)));
  }
}

/// "¿El paciente confirmó esta fecha?". `true`: la dio o confirmó el
/// paciente (no se le recuerda); `false`: se le recuerda el día anterior;
/// `null`: cerró sin responder (no se guarda nada).
Future<bool?> _preguntarSiConfirmo(BuildContext context, DateTime fecha) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿El paciente confirmó esta fecha?'),
      content: Text(
        sinCortes(
          'Si el paciente le dijo que viene el ${Fechas.corta(fecha)}, '
          'no hace falta enviarle recordatorio.',
        ),
      ),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: Espacio.sm,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No, recordárselo'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Sí, confirmó'),
        ),
      ],
    ),
  );
}

/// "Poner nueva fecha" a un control que no se cumplió: si está vencido lo
/// mueve; si se marcó "No vino", agenda el siguiente del mismo tratamiento
/// (sin cobros nuevos). Devuelve `true` si se guardó.
Future<bool> ponerNuevaFecha(
  BuildContext context,
  WidgetRef ref, {
  required String controlId,
  required String pacienteId,
}) async {
  final eleccion = await elegirCuandoVuelve(context);
  final fecha = eleccion?.fecha;
  if (fecha == null || !context.mounted) return false;
  final confirmo = await _preguntarSiConfirmo(context, fecha);
  if (confirmo == null || !context.mounted) return false;
  try {
    final control = await ref
        .read(controlesRepositoryProvider)
        .reprogramar(controlId, fecha, null, confirmado: confirmo);
    if (!context.mounted) return true;
    final cuando = sinCortes(control.fechaTexto());
    mostrarMensaje(
      context,
      confirmo
          ? 'Próximo control: $cuando. Ya confirmó: no se le enviará recordatorio.'
          : 'Próximo control: $cuando. Se le recordará el día anterior.',
    );
    refrescarRecordatorios(ref);
    refrescarControles(ref, pacienteId);
    return true;
  } on ApiError catch (e) {
    if (context.mounted) mostrarMensaje(context, e.mensaje);
    return false;
  }
}
