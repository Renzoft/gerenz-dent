import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/salud_repository.dart';

/// Pantalla de inicio (iteración 0): marca + estado de conexión con la API.
/// En la iteración 3 se convierte en el tablero "Mañana / Vencidos / Deudas".
class InicioPage extends ConsumerWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoServidorProvider);
    final nombre = ref.watch(authControllerProvider).value?.nombre;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvgPicture.asset(
                'assets/branding/logo-horizontal.svg',
                height: 96,
                semanticsLabel: 'GERENZ DENT',
              ),
              const SizedBox(height: 32),
              Text(
                nombre == null ? 'Bienvenido' : 'Bienvenido, $nombre',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                              size: 32,
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
            ],
          ),
        ),
      ),
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
