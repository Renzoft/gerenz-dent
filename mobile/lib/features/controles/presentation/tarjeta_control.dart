import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../../cuenta/data/cuenta_repository.dart';
import '../../cuenta/domain/cuenta.dart';
import '../../cuenta/presentation/registrar_pago_sheet.dart';
import '../application/controles_providers.dart';
import '../data/controles_repository.dart';
import '../domain/control.dart';
import 'agendar_control_sheet.dart';
import 'estado_visual.dart';

/// Control abierto: una acción principal (Asistió) y "Otras opciones".
class TarjetaControl extends ConsumerStatefulWidget {
  const TarjetaControl({
    super.key,
    required this.control,
    required this.pacienteNombre,
    this.destacada = true,
  });

  final Control control;
  final String pacienteNombre;

  /// Solo el control más cercano lleva "Asistió" como acción principal; los
  /// siguientes, en versión secundaria (una acción principal por pantalla).
  final bool destacada;

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
        cancelar: 'No, volver',
        peligrosa: true,
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
    await _ofrecerPago();
    if (!mounted) return;
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

  /// Tras "Asistió" (y la cuota de brackets, si aplica) se ofrece registrar
  /// lo que pagó el paciente (HU-22). Si el tratamiento no tiene deuda, no
  /// pregunta.
  Future<void> _ofrecerPago() async {
    final planId = _c.planId;
    if (planId == null) return;
    final CuentaPlan? plan;
    try {
      final cuenta = await ref
          .read(cuentaRepositoryProvider)
          .cuenta(_c.pacienteId);
      plan = cuenta.planes.where((p) => p.planId == planId).firstOrNull;
    } on ApiError {
      return; // sin conexión: se puede registrar luego desde la ficha
    }
    if (plan == null || !plan.debe || !mounted) return;
    final pagar = await confirmar(
      context,
      titulo: '¿Pagó algo hoy?',
      mensaje:
          '${plan.tratamientoNombre}: debe ${Moneda.formatear(plan.saldo)}.',
      accion: 'Registrar pago',
    );
    if (!pagar || !mounted) return;
    final ok = await mostrarRegistrarPago(
      context,
      planId: plan.planId,
      tratamiento: plan.tratamientoNombre,
      saldo: plan.saldo,
    );
    if (ok && mounted) mostrarMensaje(context, 'Pago registrado');
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

  /// Acciones menos frecuentes, con nombre y explicación (antes: menú ⋮).
  Future<void> _otrasOpciones() async {
    final eleccion = await mostrarOpciones<_OpcionControl>(
      context,
      titulo: _c.tratamientoNombre,
      opciones: [
        const Opcion(
          valor: _OpcionControl.noVino,
          icono: Icons.person_off_outlined,
          titulo: 'No vino',
          detalle: 'El paciente no asistió a este control',
        ),
        const Opcion(
          valor: _OpcionControl.cambiarFecha,
          icono: Icons.event_repeat,
          titulo: 'Cambiar fecha',
          detalle: 'Mover el control a otro día',
        ),
        if (_c.estado != EstadoControl.confirmado)
          const Opcion(
            valor: _OpcionControl.confirmo,
            icono: Icons.thumb_up_alt_outlined,
            titulo: 'El paciente confirmó',
            detalle: 'Respondió que sí vendrá',
          ),
        const Opcion(
          valor: _OpcionControl.cancelar,
          icono: Icons.cancel_outlined,
          titulo: 'Cancelar control',
          detalle: 'Ya no se hará y no se le enviará recordatorio',
          peligrosa: true,
        ),
      ],
    );
    if (!mounted || eleccion == null) return;
    switch (eleccion) {
      case _OpcionControl.noVino:
        await _cambiar(EstadoControl.noAsistio);
      case _OpcionControl.cambiarFecha:
        await _reprogramar();
      case _OpcionControl.confirmo:
        await _cambiar(EstadoControl.confirmado);
      case _OpcionControl.cancelar:
        await _cambiar(EstadoControl.cancelado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre, estado y fecha en filas propias: con letra grande nada
            // se corta a mitad de palabra.
            Text(_c.tratamientoNombre, style: textos.titleMedium),
            const SizedBox(height: Espacio.sm),
            Align(alignment: Alignment.centerLeft, child: chipDeControl(_c)),
            const SizedBox(height: Espacio.md),
            Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(
                    Icons.event_outlined,
                    size: 22,
                    color: Tokens.textoSecundario,
                  ),
                ),
                const SizedBox(width: Espacio.sm),
                Expanded(
                  child: Text(
                    sinCortes(_c.fechaTexto()),
                    style: const TextStyle(
                      fontSize: TipoTam.subtitulo,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                ),
              ],
            ),
            if (_c.vencido)
              Padding(
                padding: const EdgeInsets.only(
                  left: 22 + Espacio.sm,
                  top: Espacio.xs,
                ),
                child: Text(
                  'Vencido hace ${_c.diasAtraso} día${_c.diasAtraso == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Primitivos.ambar700,
                    fontSize: TipoTam.cuerpo,
                  ),
                ),
              ),
            if (_c.nota != null) ...[
              const SizedBox(height: Espacio.sm),
              Text(
                _c.nota!,
                style: textos.bodyMedium?.copyWith(
                  color: Tokens.textoSecundario,
                ),
              ),
            ],
            const SizedBox(height: Espacio.lg),
            // Una sola acción principal; el resto, en "Otras opciones".
            if (widget.destacada)
              FilledButton.icon(
                onPressed: _procesando
                    ? null
                    : () => _cambiar(EstadoControl.asistio),
                icon: const Icon(Icons.check),
                label: const Text('Asistió'),
              )
            else
              OutlinedButton.icon(
                onPressed: _procesando
                    ? null
                    : () => _cambiar(EstadoControl.asistio),
                icon: const Icon(Icons.check),
                label: const Text('Asistió'),
              ),
            const SizedBox(height: Espacio.sm),
            if (widget.destacada)
              OutlinedButton.icon(
                onPressed: _procesando ? null : _otrasOpciones,
                icon: const Icon(Icons.more_horiz),
                label: const Text('Otras opciones'),
              )
            else
              TextButton.icon(
                onPressed: _procesando ? null : _otrasOpciones,
                icon: const Icon(Icons.more_horiz),
                label: const Text('Otras opciones'),
              ),
          ],
        ),
      ),
    );
  }
}

enum _OpcionControl { noVino, cambiarFecha, confirmo, cancelar }

/// Fila del historial (controles cerrados): tratamiento, día y estado.
class FilaHistorial extends StatelessWidget {
  const FilaHistorial({super.key, required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          control.tratamientoNombre,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        // Día real en que se cerró; si no se conoce, la planificada.
        Text(
          Fechas.corta(control.cerradoEn ?? control.fecha),
          style: const TextStyle(
            fontSize: TipoTam.cuerpo,
            color: Tokens.textoSecundario,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacio.lg,
        vertical: Espacio.md,
      ),
      // Con letra muy grande el estado va debajo, para no aplastar el nombre.
      child: letraGrande(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                datos,
                const SizedBox(height: Espacio.sm),
                chipDeControl(control),
              ],
            )
          : Row(
              children: [
                Expanded(child: datos),
                const SizedBox(width: Espacio.sm),
                chipDeControl(control),
              ],
            ),
    );
  }
}
