import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/avisos/envio_whatsapp.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/estados.dart';
import '../../controles/application/controles_providers.dart';
import '../data/recordatorios_repository.dart';
import '../domain/mensaje_recordatorio.dart';

/// Recordatorios de mañana (HU-15, HU-16).
final recordatoriosMananaProvider =
    FutureProvider.autoDispose<List<MensajeRecordatorio>>(
      (ref) => ref.read(recordatoriosRepositoryProvider).pendientes(),
      retry: (intento, error) => null,
    );

/// Seguimientos de controles vencidos (HU-18).
final seguimientosProvider =
    FutureProvider.autoDispose<List<MensajeRecordatorio>>(
      (ref) => ref.read(recordatoriosRepositoryProvider).seguimientos(),
      retry: (intento, error) => null,
    );

enum ResultadoEnvio { enviado, noEnviado, detener }

/// Flujo de un envío (HU-16, HU-17):
/// abrir WhatsApp → el doctor envía → vuelve a la app → "¿Se envió?" → se
/// registra y el control pasa a "Recordado".
Future<ResultadoEnvio> enviarRecordatorio(
  BuildContext context,
  WidgetRef ref,
  MensajeRecordatorio m, {
  bool hayMas = false,
}) async {
  final enlace = m.enlace;
  if (enlace == null) return ResultadoEnvio.noEnviado;

  final abierto = await ref
      .read(envioWhatsappProvider)
      .abrirYEsperarRegreso(enlace);
  if (!context.mounted) return ResultadoEnvio.detener;
  if (!abierto) {
    mostrarMensaje(context, 'No se pudo abrir WhatsApp.');
    return ResultadoEnvio.detener;
  }

  final resultado = await showDialog<ResultadoEnvio>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('¿Se envió el mensaje a ${m.pacienteNombre}?'),
      actions: [
        if (hayMas)
          TextButton(
            onPressed: () => Navigator.of(context).pop(ResultadoEnvio.detener),
            child: const Text('Detener'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(ResultadoEnvio.noEnviado),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ResultadoEnvio.enviado),
          child: const Text('Sí, se envió'),
        ),
      ],
    ),
  );

  if (resultado == ResultadoEnvio.enviado) {
    try {
      await ref
          .read(recordatoriosRepositoryProvider)
          .registrarEnvio(m.controlId, m.tipo);
    } on ApiError catch (e) {
      if (context.mounted) mostrarMensaje(context, e.mensaje);
      return ResultadoEnvio.detener;
    }
  }
  return resultado ?? ResultadoEnvio.detener;
}

/// "Enviar todos uno por uno": abre WhatsApp para cada paciente pendiente.
Future<void> enviarTodos(
  BuildContext context,
  WidgetRef ref,
  List<MensajeRecordatorio> mensajes,
) async {
  final porEnviar = mensajes.where((m) => m.porEnviar).toList();
  var enviados = 0;
  for (var i = 0; i < porEnviar.length; i++) {
    if (!context.mounted) return;
    final r = await enviarRecordatorio(
      context,
      ref,
      porEnviar[i],
      hayMas: i < porEnviar.length - 1,
    );
    if (r == ResultadoEnvio.enviado) enviados++;
    if (r == ResultadoEnvio.detener) break;
  }
  refrescarRecordatorios(ref);
  if (context.mounted && enviados > 0) {
    mostrarMensaje(
      context,
      '$enviados recordatorio${enviados == 1 ? '' : 's'} enviado${enviados == 1 ? '' : 's'}',
    );
  }
}

void refrescarRecordatorios(WidgetRef ref) {
  ref.invalidate(recordatoriosMananaProvider);
  ref.invalidate(seguimientosProvider);
  refrescarControles(ref);
}
