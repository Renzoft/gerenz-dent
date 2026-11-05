import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
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

  /// El error es del monto (se muestra en el campo) o de la API (abajo).
  bool _errorDelMonto = false;

  @override
  void dispose() {
    _monto.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final monto = Moneda.leer(_monto.text);
    if (monto == null || monto <= 0) {
      setState(() {
        _error = 'Escribe cuánto pagó (ej.: 50)';
        _errorDelMonto = true;
      });
      return;
    }
    if (monto > widget.saldo + 0.001) {
      setState(() {
        _error = 'El pago supera la deuda de ${Moneda.formatear(widget.saldo)}';
        _errorDelMonto = true;
      });
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
        setState(() {
          _error = e.errores.values.firstOrNull ?? e.mensaje;
          _errorDelMonto = false;
        });
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
        left: Espacio.xl,
        right: Espacio.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Espacio.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar pago', style: textos.titleLarge),
            const SizedBox(height: Espacio.xs),
            Text(
              widget.tratamiento,
              style: const TextStyle(
                fontSize: TipoTam.cuerpo,
                color: Tokens.textoSecundario,
              ),
            ),
            const SizedBox(height: Espacio.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: ChipEstado(
                tono: Tono.aviso,
                icono: Icons.schedule,
                texto: 'Debe ${Moneda.formatear(widget.saldo)}',
              ),
            ),
            const SizedBox(height: Espacio.xl),
            TextField(
              controller: _monto,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) {
                if (_errorDelMonto && _error != null) {
                  setState(() => _error = null);
                }
              },
              decoration: InputDecoration(
                labelText: 'Monto pagado',
                prefixText: 'S/ ',
                errorText: _errorDelMonto ? _error : null,
                errorMaxLines: 2,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: Espacio.xs),
                  child: TextButton(
                    onPressed: () => setState(() {
                      _monto.text = widget.saldo.toStringAsFixed(2);
                      _error = null;
                    }),
                    child: const Text('Todo'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Espacio.xl),
            Semantics(
              header: true,
              child: Text('¿Cómo pagó?', style: textos.titleSmall),
            ),
            const SizedBox(height: Espacio.sm),
            Wrap(
              spacing: Espacio.sm,
              runSpacing: Espacio.sm,
              children: [
                for (final m in MedioPago.values)
                  ChoiceChip(
                    label: Text(m.etiqueta),
                    selected: _medio == m,
                    onSelected: (_) => setState(() => _medio = m),
                  ),
              ],
            ),
            const SizedBox(height: Espacio.xl),
            TextField(
              controller: _nota,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nota (opcional)'),
            ),
            if (!_errorDelMonto && _error != null) ...[
              Aviso(
                key: const Key('pago-error'),
                tono: Tono.peligro,
                icono: Icons.error_outline,
                texto: _error!,
              ),
              const SizedBox(height: Espacio.md),
            ],
            const SizedBox(height: Espacio.sm),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: Text(_guardando ? 'Guardando…' : 'Registrar pago'),
            ),
          ],
        ),
      ),
    );
  }
}
