import 'package:flutter/material.dart';

import '../network/api_error.dart';
import '../theme/tokens.dart';

/// Mensaje de error con botón para reintentar.
class VistaError extends StatelessWidget {
  const VistaError({
    super.key,
    required this.error,
    required this.onReintentar,
  });

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(Espacio.lg),
              decoration: const BoxDecoration(
                color: Tokens.errorSuave,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off, size: 36, color: Tokens.error),
            ),
            const SizedBox(height: Espacio.lg),
            Text(
              ApiError.desde(error).mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Espacio.xl),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de carga con un texto que explica la espera (arranque en frío).
class VistaCargando extends StatelessWidget {
  const VistaCargando({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Tokens.marcaFuerte),
            if (mensaje != null) ...[
              const SizedBox(height: Espacio.lg),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: TipoTam.cuerpo,
                  color: Tokens.textoSecundario,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pide confirmación antes de una acción. Devuelve `true` si el doctor acepta.
///
/// Con [peligrosa] el botón de confirmar va en rojo (cancelar, anular…).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  String cancelar = 'Cancelar',
  bool peligrosa = false,
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actionsOverflowButtonSpacing: Espacio.sm,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelar),
        ),
        FilledButton(
          style: peligrosa
              ? FilledButton.styleFrom(backgroundColor: Tokens.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(accion),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}

/// Aviso breve abajo de la pantalla (confirmación de éxito o error).
void mostrarMensaje(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}
