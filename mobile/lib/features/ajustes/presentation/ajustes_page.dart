import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/avisos/avisos_diarios.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
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
        padding: const EdgeInsets.fromLTRB(
          Espacio.pantalla,
          0,
          Espacio.pantalla,
          Espacio.xl,
        ),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Espacio.lg,
                vertical: Espacio.xs,
              ),
              leading: const CircleAvatar(
                backgroundColor: Tokens.marcaSuave,
                foregroundColor: Primitivos.celeste800,
                child: Icon(Icons.person_outline),
              ),
              title: Text(
                usuario?.nombre ?? '',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(usuario?.email ?? ''),
            ),
          ),
          const EncabezadoSeccion('Recordatorios'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Espacio.lg,
                vertical: Espacio.xs,
              ),
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Aviso diario'),
              subtitle: Text(
                sinCortes('Todos los días a las ${Fechas.hora(hora)}'),
                key: const Key('hora-aviso'),
              ),
              trailing: _guardando
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text(
                      'Cambiar',
                      style: TextStyle(
                        fontSize: TipoTam.cuerpo,
                        fontWeight: FontWeight.w600,
                        color: Tokens.marcaFuerte,
                      ),
                    ),
              onTap: _guardando ? null : () => _cambiarHora(hora),
            ),
          ),
          const EncabezadoSeccion('Consultorio'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Espacio.lg,
                vertical: Espacio.xs,
              ),
              leading: const Icon(Icons.medical_services_outlined),
              title: const Text('Catálogo de tratamientos'),
              subtitle: const Text('Precios, cuotas y controles sugeridos'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Rutas.catalogo),
            ),
          ),
          const SizedBox(height: Espacio.xl),
          OutlinedButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: Espacio.xl),
          const Center(
            child: Text(
              'GERENZ DENT · versión 1.3.0',
              style: TextStyle(
                fontSize: TipoTam.etiqueta,
                color: Tokens.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
