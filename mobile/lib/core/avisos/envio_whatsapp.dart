import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre WhatsApp con el mensaje escrito y espera a que el doctor vuelva a la
/// app (ADR-001, opción C). Se abstrae para poder probar el flujo sin WhatsApp.
abstract class EnvioWhatsapp {
  /// Devuelve `false` si no se pudo abrir WhatsApp.
  Future<bool> abrirYEsperarRegreso(String enlace);
}

class EnvioWhatsappReal implements EnvioWhatsapp {
  /// Si el doctor no vuelve en este tiempo, se deja de esperar.
  static const _limite = Duration(minutes: 15);

  @override
  Future<bool> abrirYEsperarRegreso(String enlace) async {
    final regreso = _esperarRegreso();
    final abierto = await launchUrl(
      Uri.parse(enlace),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto) {
      regreso.cancelar();
      return false;
    }
    await regreso.futuro;
    return true;
  }

  _Regreso _esperarRegreso() {
    final completer = Completer<void>();
    var salio = false;
    late final AppLifecycleListener oyente;
    void terminar() {
      if (!completer.isCompleted) completer.complete();
      oyente.dispose();
    }

    oyente = AppLifecycleListener(
      onHide: () => salio = true,
      onPause: () => salio = true,
      onResume: () {
        if (salio) terminar();
      },
    );
    final timer = Timer(_limite, terminar);
    return _Regreso(completer.future.whenComplete(timer.cancel), () {
      timer.cancel();
      terminar();
    });
  }
}

class _Regreso {
  _Regreso(this.futuro, this.cancelar);

  final Future<void> futuro;
  final void Function() cancelar;
}

final envioWhatsappProvider = Provider<EnvioWhatsapp>(
  (ref) => EnvioWhatsappReal(),
);
