import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../../cuenta/application/cuenta_providers.dart';
import '../../cuenta/domain/cuenta.dart';
import '../../tratamientos/data/tratamientos_repository.dart';
import '../../tratamientos/domain/tratamiento.dart';
import '../application/controles_providers.dart';
import '../data/controles_repository.dart';
import '../domain/control.dart';

/// Abre la hoja para agendar el próximo control (HU-11).
/// Devuelve el control creado, o `null` si el doctor cancela.
Future<Control?> mostrarAgendarControl(
  BuildContext context, {
  required String pacienteId,
  required String pacienteNombre,
  String? tratamientoId,
  DateTime? fechaSugerida,
}) {
  return showModalBottomSheet<Control>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => AgendarControlSheet(
      pacienteId: pacienteId,
      pacienteNombre: pacienteNombre,
      tratamientoInicial: tratamientoId,
      fechaInicial: fechaSugerida,
    ),
  );
}

/// Atajos de fecha (docs/planificacion/02-requisitos.md, HU-11).
class _Atajo {
  const _Atajo(this.etiqueta, this.calcular);

  final String etiqueta;
  final DateTime Function(DateTime hoy) calcular;
}

final _atajos = [
  _Atajo('+1 sem', (h) => h.add(const Duration(days: 7))),
  _Atajo('+15 d', (h) => h.add(const Duration(days: 15))),
  _Atajo('+1 mes', (h) => h.add(const Duration(days: 30))),
  _Atajo('+3 m', (h) => h.add(const Duration(days: 90))),
  _Atajo('+6 m', (h) => h.add(const Duration(days: 180))),
];

class AgendarControlSheet extends ConsumerStatefulWidget {
  const AgendarControlSheet({
    super.key,
    required this.pacienteId,
    required this.pacienteNombre,
    this.tratamientoInicial,
    this.fechaInicial,
  });

  final String pacienteId;
  final String pacienteNombre;
  final String? tratamientoInicial;
  final DateTime? fechaInicial;

  @override
  ConsumerState<AgendarControlSheet> createState() =>
      _AgendarControlSheetState();
}

class _AgendarControlSheetState extends ConsumerState<AgendarControlSheet> {
  final _nota = TextEditingController();
  final _hoy = Fechas.hoy();

  Tratamiento? _tratamiento;
  DateTime? _fecha;
  DateTime? _fechaSugerida;
  TimeOfDay? _hora;
  int _piezas = 1;
  bool _guardando = false;
  String? _error;

  // Cobro (solo si este control crea un plan nuevo).
  final _costo = TextEditingController();
  final _pagoHoy = TextEditingController();
  bool _costoEditado = false;
  MedioPago _medio = MedioPago.efectivo;

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaInicial;
    _fechaSugerida = widget.fechaInicial;
  }

  @override
  void dispose() {
    _nota.dispose();
    _costo.dispose();
    _pagoHoy.dispose();
    super.dispose();
  }

  /// Precio del catálogo (por pieza × piezas). El doctor puede cambiarlo.
  void _actualizarCosto() {
    final t = _tratamiento;
    if (t == null || _costoEditado || t.precioBase == null) return;
    final total = t.esPorPieza ? t.precioBase! * _piezas : t.precioBase!;
    _costo.text = total.toStringAsFixed(2);
  }

  /// El cobro se pide solo para el primer control de ese tratamiento.
  bool _esPlanNuevo(CuentaPaciente? cuenta) {
    final t = _tratamiento;
    return t != null && cuenta != null && cuenta.planActivoDe(t.id) == null;
  }

  /// Al elegir el tratamiento se preselecciona la fecha sugerida (HU-09).
  Future<void> _elegirTratamiento(Tratamiento? t) async {
    setState(() {
      _tratamiento = t;
      _error = null;
      _costoEditado = false;
      _actualizarCosto();
    });
    if (t == null || t.intervaloControlDias == null) {
      setState(() => _fechaSugerida = null);
      return;
    }
    try {
      final sugerida = await ref
          .read(controlesRepositoryProvider)
          .sugerencia(widget.pacienteId, t.id);
      if (!mounted || _tratamiento?.id != t.id) return;
      setState(() {
        _fechaSugerida = sugerida;
        if (sugerida != null) _fecha = sugerida;
      });
    } catch (_) {
      // Sin sugerencia el doctor elige la fecha a mano.
    }
  }

  Future<void> _elegirOtraFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? _hoy,
      firstDate: _hoy,
      lastDate: _hoy.add(const Duration(days: 730)),
      helpText: 'Fecha del control',
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: _hora ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Hora del control',
    );
    if (elegida != null) setState(() => _hora = elegida);
  }

  Future<void> _guardar() async {
    if (_tratamiento == null) {
      setState(() => _error = 'Elige el tratamiento');
      return;
    }
    if (_fecha == null) {
      setState(() => _error = 'Elige la fecha del control');
      return;
    }
    final planNuevo = _esPlanNuevo(
      ref.read(cuentaPacienteProvider(widget.pacienteId)).value,
    );
    double? costo;
    double? pagoHoy;
    if (planNuevo) {
      if (_costo.text.trim().isNotEmpty) {
        costo = Moneda.leer(_costo.text);
        if (costo == null || costo < 0) {
          setState(() => _error = 'Revisa el costo');
          return;
        }
      }
      if (_pagoHoy.text.trim().isNotEmpty) {
        pagoHoy = Moneda.leer(_pagoHoy.text);
        if (pagoHoy == null || pagoHoy <= 0) {
          setState(() => _error = 'Revisa el monto pagado');
          return;
        }
        if (costo != null && pagoHoy > costo) {
          setState(() => _error = 'Lo pagado no puede ser mayor que el costo');
          return;
        }
      }
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final creado = await ref
          .read(controlesRepositoryProvider)
          .agendar(
            NuevoControl(
              pacienteId: widget.pacienteId,
              tratamientoId: _tratamiento!.id,
              fecha: _fecha!,
              hora: _hora,
              nota: _nota.text,
              piezas: _tratamiento!.esPorPieza ? _piezas : null,
              costo: costo,
              pagoInicial: pagoHoy,
              medioPago: pagoHoy == null ? null : _medio.api,
            ),
          );
      if (!mounted) return;
      refrescarControles(ref, widget.pacienteId);
      Navigator.of(context).pop(creado);
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
    final catalogo = ref.watch(catalogoProvider);
    final cuenta = ref.watch(cuentaPacienteProvider(widget.pacienteId)).value;
    final textos = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: catalogo.when(
        loading: () => const SizedBox(height: 240, child: VistaCargando()),
        error: (e, _) => SizedBox(
          height: 280,
          child: VistaError(
            error: e,
            onReintentar: () => ref.invalidate(catalogoProvider),
          ),
        ),
        data: (tratamientos) {
          // Preselección cuando viene del flujo "Asistió → siguiente control".
          if (_tratamiento == null && widget.tratamientoInicial != null) {
            _tratamiento = tratamientos
                .where((t) => t.id == widget.tratamientoInicial)
                .firstOrNull;
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Próximo control', style: textos.titleLarge),
                Text(
                  widget.pacienteNombre,
                  style: textos.bodyLarge?.copyWith(color: AppColors.grisTexto),
                ),
                const SizedBox(height: 16),
                DropdownMenu<Tratamiento>(
                  key: const Key('tratamiento'),
                  expandedInsets: EdgeInsets.zero,
                  label: const Text('Tratamiento *'),
                  initialSelection: _tratamiento,
                  menuHeight: 360,
                  onSelected: _elegirTratamiento,
                  dropdownMenuEntries: [
                    for (final t in tratamientos)
                      DropdownMenuEntry(value: t, label: t.nombre),
                  ],
                ),
                if (_tratamiento?.esPorPieza ?? false) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Piezas', style: TextStyle(fontSize: 16)),
                      const Spacer(),
                      IconButton.outlined(
                        tooltip: 'Menos piezas',
                        onPressed: _piezas > 1
                            ? () => setState(() {
                                _piezas--;
                                _actualizarCosto();
                              })
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_piezas', style: textos.titleLarge),
                      ),
                      IconButton.outlined(
                        tooltip: 'Más piezas',
                        onPressed: _piezas < 32
                            ? () => setState(() {
                                _piezas++;
                                _actualizarCosto();
                              })
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('Fecha *', style: textos.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final atajo in _atajos)
                      _ChipFecha(
                        etiqueta: atajo.etiqueta,
                        fecha: atajo.calcular(_hoy),
                        seleccionada: _fecha,
                        onSeleccionar: (f) => setState(() => _fecha = f),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Otra fecha'),
                      onPressed: _elegirOtraFecha,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _fecha == null
                      ? 'Sin fecha elegida'
                      : _capitalizar(Fechas.larga(_fecha!)),
                  key: const Key('fecha-elegida'),
                  style: textos.titleMedium?.copyWith(
                    color: _fecha == null
                        ? AppColors.grisTexto
                        : AppColors.verdeOscuro,
                  ),
                ),
                if (_fechaSugerida != null)
                  Text(
                    'Sugerida por el tratamiento: ${Fechas.corta(_fechaSugerida!)}',
                    style: const TextStyle(color: AppColors.grisTexto),
                  ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                    _hora == null ? 'Hora (opcional)' : Fechas.hora(_hora!),
                  ),
                  subtitle: _hora == null
                      ? const Text(
                          'Si no la eliges, se usa la hora de apertura',
                        )
                      : null,
                  trailing: _hora == null
                      ? null
                      : IconButton(
                          tooltip: 'Quitar hora',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _hora = null),
                        ),
                  onTap: _elegirHora,
                ),
                TextField(
                  controller: _nota,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Ej.: cambio de ligas',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_esPlanNuevo(cuenta)) ..._camposCobro(textos),
                if (_error != null) ...[
                  Text(
                    _error!,
                    key: const Key('agendar-error'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando…' : 'Agendar control'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Costo (editable para descuentos) y pago del día (HU-21, HU-22).
  List<Widget> _camposCobro(TextTheme textos) {
    final t = _tratamiento!;
    final mensual = t.tipoPrecio == TipoPrecio.inicialMasMensual;
    final cuota = t.precioMensual == null
        ? ''
        : Moneda.formatear(t.precioMensual!);
    return [
      const Divider(height: 24),
      Text('Cobro', style: textos.titleSmall),
      const SizedBox(height: 8),
      TextField(
        key: const Key('costo'),
        controller: _costo,
        onChanged: (_) => _costoEditado = true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: mensual ? 'Pago inicial' : 'Costo del tratamiento',
          helperText: mensual && cuota.isNotEmpty
              ? 'Luego $cuota cada vez que asista'
              : 'Puedes cambiarlo si haces un descuento',
          prefixText: 'S/ ',
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('pago-hoy'),
        controller: _pagoHoy,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Pagó hoy (opcional)',
          prefixText: 'S/ ',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (_pagoHoy.text.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in MedioPago.values)
              ChoiceChip(
                label: Text(m.etiqueta),
                selected: _medio == m,
                onSelected: (_) => setState(() => _medio = m),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
    ];
  }

  static String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

class _ChipFecha extends StatelessWidget {
  const _ChipFecha({
    required this.etiqueta,
    required this.fecha,
    required this.seleccionada,
    required this.onSeleccionar,
  });

  final String etiqueta;
  final DateTime fecha;
  final DateTime? seleccionada;
  final ValueChanged<DateTime> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected:
          seleccionada != null && DateUtils.isSameDay(seleccionada, fecha),
      onSelected: (_) => onSeleccionar(fecha),
    );
  }
}
