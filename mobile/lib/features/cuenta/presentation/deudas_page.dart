import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../application/cuenta_providers.dart';

/// Pestaña Deudas (P5, HU-23): total y pacientes de mayor a menor deuda.
///
/// "Debe" va en ámbar (pendiente), no en rojo: el rojo queda para errores.
class DeudasPage extends ConsumerWidget {
  const DeudasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudas = ref.watch(deudasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Deudas')),
      body: deudas.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Espacio.pantalla),
          child: Column(children: [TarjetaEsqueleto()]),
        ),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(deudasProvider),
        ),
        data: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(deudasProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espacio.pantalla,
              Espacio.xs,
              Espacio.pantalla,
              Espacio.xl,
            ),
            children: [
              _Resumen(total: r.total, cantidad: r.pacientes.length),
              if (r.pacientes.isNotEmpty) ...[
                const EncabezadoSeccion('De mayor a menor'),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < r.pacientes.length; i++) ...[
                        if (i > 0) const Divider(indent: Espacio.lg),
                        _FilaDeuda(
                          nombre: r.pacientes[i].nombre,
                          archivado: r.pacientes[i].archivado,
                          monto: r.pacientes[i].deuda,
                          onTap: () => context.push(
                            Rutas.paciente(r.pacientes[i].pacienteId),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.total, required this.cantidad});

  final double total;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final hayDeuda = total > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Te deben',
              style: TextStyle(
                fontSize: TipoTam.cuerpo,
                color: Tokens.textoSecundario,
              ),
            ),
            const SizedBox(height: Espacio.xs),
            Text(
              Moneda.formatear(total),
              key: const Key('total-deudas'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: hayDeuda ? Primitivos.ambar800 : Tokens.texto,
              ),
            ),
            const SizedBox(height: Espacio.sm),
            ChipEstado(
              tono: hayDeuda ? Tono.aviso : Tono.exito,
              icono: hayDeuda ? Icons.schedule : Icons.check_circle_outline,
              texto: hayDeuda
                  ? '$cantidad paciente${cantidad == 1 ? '' : 's'} con deuda'
                  : 'Nadie tiene deuda pendiente',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDeuda extends StatelessWidget {
  const _FilaDeuda({
    required this.nombre,
    required this.archivado,
    required this.monto,
    required this.onTap,
  });

  final String nombre;
  final bool archivado;
  final double monto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espacio.lg,
            Espacio.md,
            Espacio.sm,
            Espacio.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: Theme.of(context).textTheme.titleSmall),
                    if (archivado)
                      const Text(
                        'Archivado',
                        style: TextStyle(
                          fontSize: TipoTam.cuerpo,
                          color: Tokens.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Espacio.sm),
              Text(
                Moneda.formatear(monto),
                style: const TextStyle(
                  fontSize: TipoTam.cuerpo,
                  fontWeight: FontWeight.w700,
                  color: Primitivos.ambar800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Icon(Icons.chevron_right, color: Tokens.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}
