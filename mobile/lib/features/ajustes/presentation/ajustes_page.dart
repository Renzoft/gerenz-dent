import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/avisos/avisos_diarios.dart';
import '../../../core/config/env.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/sesion.dart';
import '../../recordatorios/application/recordatorios_providers.dart';
import '../../recordatorios/data/recordatorios_repository.dart';

/// Ajustes: hora del aviso diario (HU-20), cuenta y cerrar sesión.
class AjustesPage extends ConsumerStatefulWidget {
  const AjustesPage({super.key});

  @override
  ConsumerState<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends ConsumerState<AjustesPage> {
  bool _guardando = false;

  Future<void> _cambiarHora(TimeOfDay actual) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: actual,
      helpText: 'Hora del aviso diario',
    );
    if (elegida == null || elegida == actual || !mounted) return;
    setState(() => _guardando = true);
    try {
      final hora = await ref
          .read(recordatoriosRepositoryProvider)
          .cambiarHoraAviso(elegida);
      final usuario = ref.read(authControllerProvider).value;
      if (usuario != null) {
        await ref
            .read(authControllerProvider.notifier)
            .actualizarUsuario(usuario.conHora(hora));
      }
      await _reprogramar(hora);
      if (mounted) {
        mostrarMensaje(context, 'El aviso llegará a las ${Fechas.hora(hora)}');
      }
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Usa la cantidad de mañana si ya está cargada.
  Future<void> _reprogramar(TimeOfDay hora) async {
    final manana = ref.read(recordatoriosMananaProvider).value;
    try {
      await ref
          .read(servicioAvisosProvider)
          .programar(
            hora: hora,
            pendientesHoy: manana?.where((m) => m.porEnviar).length,
          );
    } catch (_) {}
  }

  Future<void> _probarAviso() async {
    final avisos = ref.read(servicioAvisosProvider);
    final permitido = await avisos.pedirPermiso();
    if (!permitido) {
      if (mounted) {
        mostrarMensaje(
          context,
          'Activa las notificaciones de GERENZ DENT en los ajustes del teléfono.',
        );
      }
      return;
    }
    await avisos.probar();
  }

  Future<void> _cerrarSesion() async {
    final ok = await confirmar(
      context,
      titulo: 'Cerrar sesión',
      mensaje: 'Tendrás que ingresar tu correo y contraseña de nuevo.',
      accion: 'Cerrar sesión',
    );
    if (!ok) return;
    try {
      await ref.read(servicioAvisosProvider).cancelarTodos();
    } catch (_) {}
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    final hora = usuario?.horaNotificacion ?? Usuario.horaAvisoPorDefecto;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(usuario?.nombre ?? ''),
            subtitle: Text(usuario?.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Aviso diario de recordatorios'),
            subtitle: Text(
              'Todos los días a las ${Fechas.hora(hora)}',
              key: const Key('hora-aviso'),
            ),
            trailing: _guardando
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : const Icon(Icons.edit),
            onTap: _guardando ? null : () => _cambiarHora(hora),
          ),
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: const Text('Probar aviso'),
            subtitle: const Text('Muestra ahora un aviso de ejemplo'),
            onTap: _probarAviso,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: _cerrarSesion,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('GERENZ DENT'),
            subtitle: Text('Versión 0.4.0 · ${Env.apiUrl}'),
          ),
        ],
      ),
    );
  }
}
