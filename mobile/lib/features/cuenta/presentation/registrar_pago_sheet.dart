import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../data/cuenta_repository.dart';
import '../domain/cuenta.dart';

/// Abre la hoja "Registrar pago" (HU-22). Devuelve `true` si se registró.
Future<bool> mostrarRegistrarPago(
  BuildContext context, {
  required String planId,
  required String tratamiento,
  required double saldo,
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => RegistrarPagoSheet(
      planId: planId,
      tratamiento: tratamiento,
      saldo: saldo,
    ),
  );
  return r ?? false;
}

class RegistrarPagoSheet extends ConsumerStatefulWidget {
  const RegistrarPagoSheet({
    super.key,
    required this.planId,
    required this.tratamiento,
    required this.saldo,
  });

  final String planId;
  final String tratamiento;
  final double saldo;

  @override
  ConsumerState<RegistrarPagoSheet> createState() => _RegistrarPagoSheetState();
}

class _RegistrarPagoSheetState extends ConsumerState<RegistrarPagoSheet> {
  final _monto = TextEditingController();
  final _nota = TextEditingController();
  MedioPago _medio = MedioPago.efectivo;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = Moneda.leer(_monto.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingresa el monto pagado');
      return;
    }
    if (monto > widget.saldo + 0.001) {
      setState(
        () => _error =
            'El pago supera la deuda de ${Moneda.formatear(widget.saldo)}',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(cuentaRepositoryProvider)
          .registrarPago(
            widget.planId,
            monto: monto,
            medio: _medio,
            nota: _nota.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _error = e.errores.values.firstOrNull ?? e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar pago', style: textos.titleLarge),
            Text(
              '${widget.tratamiento} · debe ${Moneda.formatear(widget.saldo)}',
              style: textos.bodyLarge?.copyWith(color: AppColors.grisTexto),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monto,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto pagado *',
                prefixText: 'S/ ',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: () => setState(
                    () => _monto.text = widget.saldo.toStringAsFixed(2),
                  ),
                  child: const Text('Todo'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Medio de pago', style: textos.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in MedioPago.values)
                  ChoiceChip(
                    label: Text(m.etiqueta),
                    selected: _medio == m,
                    onSelected: (_) => setState(() => _medio = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nota,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              Text(
                _error!,
                key: const Key('pago-error'),
                style: const TextStyle(color: AppColors.error),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando…' : 'Registrar pago'),
            ),
          ],
        ),
      ),
    );
  }
}
