import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../controles/application/controles_providers.dart';
import '../../controles/domain/control.dart';
import '../../auth/application/auth_controller.dart';
import '../data/salud_repository.dart';

/// Inicio: estado de conexión, controles vencidos y próximos 7 días.
/// En la iteración 3 se agrega "Recordar para mañana" con el envío por WhatsApp.
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoServidorProvider);
    final nombre = ref.watch(authControllerProvider).value?.nombre;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(estadoServidorProvider);
            ref.invalidate(agendaSemanaProvider);
            ref.invalidate(vencidosProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/branding/icono-app.svg',
                    height: 44,
                    semanticsLabel: 'GERENZ DENT',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombre == null ? 'Bienvenido' : 'Bienvenido, $nombre',
                      style: textos.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: estado.when(
                    loading: () => const _EstadoConexion(
                      icono: SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      titulo: 'Conectando con el consultorio…',
                      detalle:
                          'La primera conexión del día puede tardar hasta 1 minuto.',
                    ),
                    data: (disponible) => disponible
                        ? const _EstadoConexion(
                            icono: Icon(
                              Icons.check_circle,
                              color: AppColors.verde,
                              size: 28,
                            ),
                            titulo: 'Conectado',
                          )
                        : _ErrorConexion(
                            onReintentar: () =>
                                ref.invalidate(estadoServidorProvider),
                          ),
                    error: (_, _) => _ErrorConexion(
                      onReintentar: () =>
                          ref.invalidate(estadoServidorProvider),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SeccionControles(
                titulo: 'Vencidos',
                vacio: 'No hay controles vencidos.',
                proveedor: vencidosProvider,
                colorTitulo: AppColors.error,
              ),
              const SizedBox(height: 24),
              _SeccionControles(
                titulo: 'Próximos 7 días',
                vacio: 'No hay controles en los próximos 7 días.',
                proveedor: agendaSemanaProvider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeccionControles extends ConsumerWidget {
  const _SeccionControles({
    required this.titulo,
    required this.vacio,
    required this.proveedor,
    this.colorTitulo,
  });

  final String titulo;
  final String vacio;
  final FutureProvider<List<Control>> proveedor;
  final Color? colorTitulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controles = ref.watch(proveedor);
    final textos = Theme.of(context).textTheme;
    final cantidad = controles.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          cantidad == null ? titulo : '$titulo ($cantidad)',
          style: textos.titleMedium?.copyWith(color: colorTitulo),
        ),
        const SizedBox(height: 4),
        controles.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            ApiError.desde(e).mensaje,
            style: const TextStyle(color: AppColors.error),
          ),
          data: (lista) => lista.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    vacio,
                    style: const TextStyle(color: AppColors.grisTexto),
                  ),
                )
              : Column(
                  children: [for (final c in lista) _FilaAgenda(control: c)],
                ),
        ),
      ],
    );
  }
}

class _FilaAgenda extends StatelessWidget {
  const _FilaAgenda({required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final paciente = control.paciente;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 60,
      title: Text(paciente?.nombre ?? '', style: const TextStyle(fontSize: 17)),
      subtitle: Text(
        control.vencido
            ? '${control.tratamientoNombre} · hace ${control.diasAtraso} día${control.diasAtraso == 1 ? '' : 's'}'
            : '${control.tratamientoNombre} · ${control.fechaTexto()}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Rutas.paciente(control.pacienteId)),
    );
  }
}

class _EstadoConexion extends StatelessWidget {
  const _EstadoConexion({
    required this.icono,
    required this.titulo,
    this.detalle,
  });

  final Widget icono;
  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        icono,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.titleMedium),
              if (detalle != null) ...[
                const SizedBox(height: 4),
                Text(
                  detalle!,
                  style: textos.bodyMedium?.copyWith(
                    color: AppColors.grisTexto,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorConexion extends StatelessWidget {
  const _ErrorConexion({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EstadoConexion(
          icono: Icon(Icons.cloud_off, color: AppColors.error, size: 32),
          titulo: 'No se pudo conectar',
          detalle: 'Revisa tu internet e inténtalo de nuevo.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
