import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../application/controles_providers.dart';
import '../data/controles_repository.dart';
import '../domain/control.dart';
import 'agendar_control_sheet.dart';

/// Control abierto con sus acciones: Asistió · No vino · Reprogramar · más.
class TarjetaControl extends ConsumerStatefulWidget {
  const TarjetaControl({
    super.key,
    required this.control,
    required this.pacienteNombre,
  });

  final Control control;
  final String pacienteNombre;

  @override
  ConsumerState<TarjetaControl> createState() => _TarjetaControlState();
}

class _TarjetaControlState extends ConsumerState<TarjetaControl> {
  bool _procesando = false;

  Control get _c => widget.control;

  Future<void> _cambiar(EstadoControl estado) async {
    if (estado == EstadoControl.cancelado) {
      final ok = await confirmar(
        context,
        titulo: 'Cancelar control',
        mensaje:
            'El control de ${_c.tratamientoNombre} del ${Fechas.corta(_c.fecha)} '
            'quedará cancelado y no se enviará recordatorio.',
        accion: 'Cancelar control',
      );
      if (!ok) return;
    }
    setState(() => _procesando = true);
    try {
      final cambio = await ref
          .read(controlesRepositoryProvider)
          .cambiarEstado(_c.id, estado);
      if (!mounted) return;
      // Primero se propone el siguiente control y recién después se refresca:
      // al refrescar, esta tarjeta desaparece (el control quedó cerrado).
      if (estado == EstadoControl.asistio) {
        await _proponerSiguiente(cambio.siguienteFechaSugerida);
      } else {
        mostrarMensaje(context, 'Control marcado: ${estado.etiqueta}');
      }
      if (mounted) refrescarControles(ref, _c.pacienteId);
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  /// HU-12: al marcar "Asistió" se ofrece agendar el siguiente control con la
  /// fecha sugerida por el tratamiento (brackets → +1 mes).
  Future<void> _proponerSiguiente(DateTime? sugerida) async {
    if (sugerida == null) {
      mostrarMensaje(context, 'Asistencia registrada');
      return;
    }
    final agendar = await confirmar(
      context,
      titulo: '¿Agendar el siguiente control?',
      mensaje:
          '${_c.tratamientoNombre}: se sugiere el ${Fechas.larga(sugerida)}.',
      accion: 'Agendar',
    );
    if (!agendar || !mounted) return;
    await mostrarAgendarControl(
      context,
      pacienteId: _c.pacienteId,
      pacienteNombre: widget.pacienteNombre,
      tratamientoId: _c.tratamientoId,
      fechaSugerida: sugerida,
    );
  }

  Future<void> _reprogramar() async {
    final hoy = Fechas.hoy();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _c.fecha.isBefore(hoy) ? hoy : _c.fecha,
      firstDate: hoy,
      lastDate: hoy.add(const Duration(days: 730)),
      helpText: 'Nueva fecha',
    );
    if (fecha == null || !mounted) return;
    setState(() => _procesando = true);
    try {
      await ref
          .read(controlesRepositoryProvider)
          .reprogramar(_c.id, fecha, _c.hora);
      if (!mounted) return;
      refrescarControles(ref, _c.pacienteId);
      mostrarMensaje(context, 'Control movido al ${Fechas.corta(fecha)}');
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_c.tratamientoNombre, style: textos.titleMedium),
                ),
                _ChipEstado(control: _c),
                PopupMenuButton<EstadoControl>(
                  tooltip: 'Más acciones',
                  enabled: !_procesando,
                  onSelected: _cambiar,
                  itemBuilder: (_) => [
                    if (_c.estado != EstadoControl.confirmado)
                      const PopupMenuItem(
                        value: EstadoControl.confirmado,
                        child: Text('El paciente confirmó'),
                      ),
                    const PopupMenuItem(
                      value: EstadoControl.cancelado,
                      child: Text('Cancelar control'),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              _c.fechaTexto(),
              style: textos.titleLarge?.copyWith(
                color: _c.vencido ? AppColors.error : AppColors.verdeOscuro,
              ),
            ),
            if (_c.vencido)
              Text(
                'Vencido hace ${_c.diasAtraso} día${_c.diasAtraso == 1 ? '' : 's'}',
                style: const TextStyle(color: AppColors.error),
              ),
            if (_c.nota != null) ...[
              const SizedBox(height: 4),
              Text(
                _c.nota!,
                style: const TextStyle(color: AppColors.grisTexto),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _procesando
                        ? null
                        : () => _cambiar(EstadoControl.asistio),
                    child: const Text('Asistió'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _procesando
                        ? null
                        : () => _cambiar(EstadoControl.noAsistio),
                    child: const Text('No vino'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _procesando ? null : _reprogramar,
              icon: const Icon(Icons.event_repeat),
              label: const Text('Reprogramar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final color = control.vencido ? AppColors.error : control.estado.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        control.vencido ? 'Vencido' : control.estado.etiqueta,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Fila del historial (controles cerrados).
class FilaHistorial extends StatelessWidget {
  const FilaHistorial({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 12, color: control.estado.color),
      title: Text(control.tratamientoNombre),
      subtitle: Text(Fechas.corta(control.fecha)),
      trailing: Text(
        control.estado.etiqueta,
        style: TextStyle(
          color: control.estado.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
