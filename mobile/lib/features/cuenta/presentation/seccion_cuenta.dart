import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../application/cuenta_providers.dart';
import '../data/cuenta_repository.dart';
import '../domain/cuenta.dart';
import 'registrar_pago_sheet.dart';

/// Deuda del paciente en su ficha (HU-23, HU-24).
class SeccionCuenta extends ConsumerWidget {
  const SeccionCuenta({super.key, required this.pacienteId});

  final String pacienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuenta = ref.watch(cuentaPacienteProvider(pacienteId));
    final textos = Theme.of(context).textTheme;

    return cuenta.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(
        ApiError.desde(e).mensaje,
        style: const TextStyle(color: AppColors.error),
      ),
      data: (c) {
        if (c.planes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Deuda', style: textos.titleMedium),
                const Spacer(),
                Text(
                  Moneda.formatear(c.deuda),
                  key: const Key('deuda-total'),
                  style: textos.titleLarge?.copyWith(
                    color: c.deuda > 0
                        ? AppColors.error
                        : AppColors.verdeOscuro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final plan in c.planes)
              _TarjetaPlan(pacienteId: pacienteId, plan: plan),
          ],
        );
      },
    );
  }
}

class _TarjetaPlan extends ConsumerWidget {
  const _TarjetaPlan({required this.pacienteId, required this.plan});

  final String pacienteId;
  final CuentaPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _verDetalle(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.piezas == null
                          ? plan.tratamientoNombre
                          : '${plan.tratamientoNombre} · ${plan.piezas} pieza${plan.piezas == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total ${Moneda.formatear(plan.totalCargos)} · '
                'Pagado ${Moneda.formatear(plan.totalPagos)}',
                style: const TextStyle(color: AppColors.grisTexto),
              ),
              Text(
                plan.debe
                    ? 'Debe ${Moneda.formatear(plan.saldo)}'
                    : 'Pagado por completo',
                style: TextStyle(
                  color: plan.debe ? AppColors.error : AppColors.verdeOscuro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (plan.debe) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _pagar(context, ref),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Registrar pago'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pagar(BuildContext context, WidgetRef ref) async {
    final ok = await mostrarRegistrarPago(
      context,
      planId: plan.planId,
      tratamiento: plan.tratamientoNombre,
      saldo: plan.saldo,
    );
    if (ok) {
      refrescarCuenta(ref, pacienteId);
      if (context.mounted) mostrarMensaje(context, 'Pago registrado');
    }
  }

  Future<void> _verDetalle(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _DetallePlan(pacienteId: pacienteId, planId: plan.planId),
    );
  }
}

/// Movimientos de un tratamiento: ajustar/anular cargos, anular pagos y
/// agregar cargos manuales (HU-21, HU-25).
class _DetallePlan extends ConsumerWidget {
  const _DetallePlan({required this.pacienteId, required this.planId});

  final String pacienteId;
  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuenta = ref.watch(cuentaPacienteProvider(pacienteId));
    final plan = cuenta.value?.planes
        .where((p) => p.planId == planId)
        .firstOrNull;
    if (plan == null) {
      return const SizedBox(height: 200, child: VistaCargando());
    }
    final textos = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(plan.tratamientoNombre, style: textos.titleLarge),
          Text(
            plan.debe
                ? 'Debe ${Moneda.formatear(plan.saldo)}'
                : 'Pagado por completo',
            style: TextStyle(
              color: plan.debe ? AppColors.error : AppColors.verdeOscuro,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Cargos', style: textos.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _agregarCargo(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          for (final c in plan.cargos)
            _FilaMovimiento(
              titulo: c.titulo,
              fecha: c.fecha,
              monto: c.monto,
              anulado: c.anulado,
              motivoAnulacion: c.motivoAnulacion,
              acciones: c.anulado
                  ? const []
                  : [
                      _Accion(
                        'Cambiar monto (descuento)',
                        () => _ajustar(context, ref, c),
                      ),
                      _Accion(
                        'Anular cargo',
                        () => _anularCargo(context, ref, c),
                      ),
                    ],
            ),
          const SizedBox(height: 16),
          Text('Pagos', style: textos.titleMedium),
          if (plan.pagos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no hay pagos.',
                style: TextStyle(color: AppColors.grisTexto),
              ),
            ),
          for (final p in plan.pagos)
            _FilaMovimiento(
              titulo: p.medio.etiqueta + (p.nota == null ? '' : ' · ${p.nota}'),
              fecha: p.fecha,
              monto: p.monto,
              anulado: p.anulado,
              motivoAnulacion: p.motivoAnulacion,
              esPago: true,
              acciones: p.anulado
                  ? const []
                  : [
                      _Accion(
                        'Anular pago',
                        () => _anularPago(context, ref, p),
                      ),
                    ],
            ),
        ],
      ),
    );
  }

  Future<void> _ejecutar(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() accion,
    String exito,
  ) async {
    try {
      await accion();
      refrescarCuenta(ref, pacienteId);
      if (context.mounted) mostrarMensaje(context, exito);
    } on ApiError catch (e) {
      if (context.mounted) {
        mostrarMensaje(context, e.errores.values.firstOrNull ?? e.mensaje);
      }
    }
  }

  Future<void> _ajustar(BuildContext context, WidgetRef ref, Cargo c) async {
    final texto = await _pedirTexto(
      context,
      titulo: 'Cambiar monto',
      etiqueta: 'Nuevo monto',
      inicial: c.monto.toStringAsFixed(2),
      numerico: true,
    );
    final monto = Moneda.leer(texto);
    if (monto == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(cuentaRepositoryProvider).ajustarCargo(c.id, monto),
      'Monto actualizado',
    );
  }

  Future<void> _anularCargo(
    BuildContext context,
    WidgetRef ref,
    Cargo c,
  ) async {
    final motivo = await _pedirTexto(
      context,
      titulo: 'Anular cargo',
      etiqueta: 'Motivo (ej.: no se cobró este mes)',
    );
    if (motivo == null || motivo.trim().isEmpty || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(cuentaRepositoryProvider).anularCargo(c.id, motivo),
      'Cargo anulado',
    );
  }

  Future<void> _anularPago(BuildContext context, WidgetRef ref, Pago p) async {
    final motivo = await _pedirTexto(
      context,
      titulo: 'Anular pago',
      etiqueta: 'Motivo (ej.: registrado por error)',
    );
    if (motivo == null || motivo.trim().isEmpty || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(cuentaRepositoryProvider).anularPago(p.id, motivo),
      'Pago anulado',
    );
  }

  Future<void> _agregarCargo(BuildContext context, WidgetRef ref) async {
    final descripcion = await _pedirTexto(
      context,
      titulo: 'Agregar cargo',
      etiqueta: 'Descripción (ej.: resina adicional)',
    );
    if (descripcion == null || descripcion.trim().isEmpty || !context.mounted) {
      return;
    }
    final monto = Moneda.leer(
      await _pedirTexto(
        context,
        titulo: 'Agregar cargo',
        etiqueta: 'Monto',
        numerico: true,
      ),
    );
    if (monto == null || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref
          .read(cuentaRepositoryProvider)
          .agregarCargo(planId, descripcion.trim(), monto),
      'Cargo agregado',
    );
  }
}

class _Accion {
  const _Accion(this.etiqueta, this.alElegir);

  final String etiqueta;
  final VoidCallback alElegir;
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.titulo,
    required this.fecha,
    required this.monto,
    required this.anulado,
    required this.acciones,
    this.motivoAnulacion,
    this.esPago = false,
  });

  final String titulo;
  final DateTime fecha;
  final double monto;
  final bool anulado;
  final String? motivoAnulacion;
  final bool esPago;
  final List<_Accion> acciones;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(
      decoration: anulado ? TextDecoration.lineThrough : null,
      color: anulado ? AppColors.grisTexto : null,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(titulo, style: estilo),
      subtitle: Text(
        anulado
            ? '${Fechas.corta(fecha)} · Anulado: ${motivoAnulacion ?? ''}'
            : Fechas.corta(fecha),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${esPago ? '−' : ''}${Moneda.formatear(monto)}',
            style: estilo.copyWith(
              fontWeight: FontWeight.w600,
              color: anulado
                  ? AppColors.grisTexto
                  : (esPago ? AppColors.verdeOscuro : null),
            ),
          ),
          if (acciones.isNotEmpty)
            PopupMenuButton<_Accion>(
              tooltip: 'Opciones',
              onSelected: (a) => a.alElegir(),
              itemBuilder: (_) => [
                for (final a in acciones)
                  PopupMenuItem(value: a, child: Text(a.etiqueta)),
              ],
            ),
        ],
      ),
    );
  }
}

Future<String?> _pedirTexto(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String? inicial,
  bool numerico = false,
}) {
  final controlador = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: controlador,
        autofocus: true,
        keyboardType: numerico
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixText: numerico ? 'S/ ' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controlador.text),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}
