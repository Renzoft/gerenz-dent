import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../application/cuenta_providers.dart';

/// Pestaña Deudas (P5, HU-23): total y pacientes de mayor a menor deuda.
class DeudasPage extends ConsumerWidget {
  const DeudasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudas = ref.watch(deudasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Deudas')),
      body: deudas.when(
        loading: () => const VistaCargando(),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(deudasProvider),
        ),
        data: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(deudasProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Te deben',
                        style: TextStyle(
                          color: AppColors.grisTexto,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        Moneda.formatear(r.total),
                        key: const Key('total-deudas'),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: r.total > 0
                                  ? AppColors.error
                                  : AppColors.verdeOscuro,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        r.pacientes.isEmpty
                            ? 'Nadie tiene deuda pendiente'
                            : '${r.pacientes.length} paciente${r.pacientes.length == 1 ? '' : 's'} con deuda',
                        style: const TextStyle(color: AppColors.grisTexto),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final d in r.pacientes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 60,
                  title: Text(d.nombre, style: const TextStyle(fontSize: 17)),
                  subtitle: d.archivado ? const Text('Archivado') : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        Moneda.formatear(d.deuda),
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push(Rutas.paciente(d.pacienteId)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
