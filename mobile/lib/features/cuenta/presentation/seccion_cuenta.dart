import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../application/cuenta_providers.dart';
import '../data/cuenta_repository.dart';
import '../domain/cuenta.dart';
import 'registrar_pago_sheet.dart';

/// Pagos del paciente en su ficha (HU-23, HU-24): deuda total y, por cada
/// tratamiento, cuánto pagó, cuánto debe y "Registrar pago".
class SeccionCuenta extends ConsumerWidget {
  const SeccionCuenta({super.key, required this.pacienteId});

  final String pacienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuenta = ref.watch(cuentaPacienteProvider(pacienteId));

    return cuenta.when(
      skipLoadingOnRefresh: true,
      loading: () => const TarjetaEsqueleto(),
      error: (e, _) => _ErrorCuenta(
        error: e,
        onReintentar: () => ref.invalidate(cuentaPacienteProvider(pacienteId)),
      ),
      data: (c) {
        if (c.planes.isEmpty) {
          return const EstadoVacio(
            icono: Icons.payments_outlined,
            texto: 'Este paciente no tiene tratamientos con cobro.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResumenDeuda(deuda: c.deuda),
            const EncabezadoSeccion('Por tratamiento'),
            for (final plan in c.planes) ...[
              _TarjetaPlan(pacienteId: pacienteId, plan: plan),
              const SizedBox(height: Espacio.md),
            ],
          ],
        );
      },
    );
  }
}

class _ResumenDeuda extends StatelessWidget {
  const _ResumenDeuda({required this.deuda});

  final double deuda;

  @override
  Widget build(BuildContext context) {
    final debe = deuda > 0;
    final tono = debe ? Tono.aviso : Tono.exito;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deuda total',
              style: TextStyle(
                fontSize: TipoTam.cuerpo,
                color: Tokens.textoSecundario,
              ),
            ),
            const SizedBox(height: Espacio.xs),
            Text(
              Moneda.formatear(deuda),
              key: const Key('deuda-total'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: debe ? Primitivos.ambar800 : Tokens.texto,
              ),
            ),
            const SizedBox(height: Espacio.sm),
            ChipEstado(
              tono: tono,
              icono: debe ? Icons.schedule : Icons.check_circle_outline,
              texto: debe ? 'Tiene pagos pendientes' : 'Está al día',
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCuenta extends StatelessWidget {
  const _ErrorCuenta({required this.error, required this.onReintentar});

  final Object error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Aviso(
          tono: Tono.peligro,
          icono: Icons.cloud_off,
          texto: ApiError.desde(error).mensaje,
        ),
        const SizedBox(height: Espacio.sm),
        OutlinedButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _TarjetaPlan extends ConsumerWidget {
  const _TarjetaPlan({required this.pacienteId, required this.plan});

  final String pacienteId;
  final CuentaPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = plan.totalCargos;
    final avance = total <= 0 ? 1.0 : (plan.totalPagos / total).clamp(0.0, 1.0);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _verDetalle(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(Espacio.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                plan.piezas == null
                    ? plan.tratamientoNombre
                    : '${plan.tratamientoNombre} · ${plan.piezas} pieza${plan.piezas == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: Espacio.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: plan.debe
                    ? ChipEstado(
                        tono: Tono.aviso,
                        icono: Icons.schedule,
                        texto: 'Debe ${Moneda.formatear(plan.saldo)}',
                      )
                    : const ChipEstado(
                        tono: Tono.exito,
                        icono: Icons.check_circle_outline,
                        texto: 'Pagado por completo',
                      ),
              ),
              const SizedBox(height: Espacio.md),
              Semantics(
                label: 'Pagado ${(avance * 100).round()} por ciento',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Radios.pildora),
                  child: LinearProgressIndicator(value: avance, minHeight: 8),
                ),
              ),
              const SizedBox(height: Espacio.sm),
              Text(
                'Total ${Moneda.formatear(plan.totalCargos)} · '
                'Pagado ${Moneda.formatear(plan.totalPagos)}',
                style: const TextStyle(
                  fontSize: TipoTam.cuerpo,
                  color: Tokens.textoSecundario,
                ),
              ),
              const SizedBox(height: Espacio.md),
              if (plan.debe) ...[
                FilledButton.icon(
                  onPressed: () => _pagar(context, ref),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Registrar pago'),
                ),
                const SizedBox(height: Espacio.xs),
              ],
              TextButton.icon(
                onPressed: () => _verDetalle(context, ref),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver cobros y pagos'),
              ),
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
              color: plan.debe ? Primitivos.ambar800 : Primitivos.verde800,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Cobros', style: textos.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _agregarCargo(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Agregar cobro'),
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
                        'Anular cobro',
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
                style: TextStyle(color: Tokens.textoSecundario),
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
      titulo: 'Anular cobro',
      etiqueta: 'Motivo (ej.: no se cobró este mes)',
    );
    if (motivo == null || motivo.trim().isEmpty || !context.mounted) return;
    await _ejecutar(
      context,
      ref,
      () => ref.read(cuentaRepositoryProvider).anularCargo(c.id, motivo),
      'Cobro anulado',
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
      titulo: 'Agregar cobro',
      etiqueta: 'Descripción (ej.: resina adicional)',
    );
    if (descripcion == null || descripcion.trim().isEmpty || !context.mounted) {
      return;
    }
    final monto = Moneda.leer(
      await _pedirTexto(
        context,
        titulo: 'Agregar cobro',
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
      'Cobro agregado',
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
      color: anulado ? Tokens.textoSecundario : null,
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
                  ? Tokens.textoSecundario
                  : (esPago ? Primitivos.verde800 : null),
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
