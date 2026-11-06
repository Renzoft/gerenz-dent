import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../../controles/application/controles_providers.dart';
import '../../controles/domain/control.dart';
import '../../controles/presentation/estado_visual.dart';

/// Agenda: el mes en un calendario y, debajo, los controles del día elegido.
///
/// Muestra los controles por venir y también los que ya asistieron o no
/// vinieron (los cancelados no). Tocar un control abre la ficha del paciente.
class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key, this.hoy});

  /// Solo para pruebas: fija el día de hoy.
  final DateTime? hoy;

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  late final DateTime _hoy = Fechas.hoy(widget.hoy);
  late DateTime _mes = DateTime(_hoy.year, _hoy.month);
  late DateTime _dia = _hoy;

  void _cambiarMes(int delta) {
    setState(() {
      _mes = DateTime(_mes.year, _mes.month + delta);
      // Al cambiar de mes se elige el día 1 (u hoy si es el mes actual).
      _dia = _mes.year == _hoy.year && _mes.month == _hoy.month ? _hoy : _mes;
    });
  }

  void _irAHoy() => setState(() {
    _mes = DateTime(_hoy.year, _hoy.month);
    _dia = _hoy;
  });

  @override
  Widget build(BuildContext context) {
    final controles = ref.watch(agendaMesProvider(_mes));
    final porDia = <DateTime, List<Control>>{};
    for (final c in controles.value ?? const <Control>[]) {
      final d = DateTime(c.fecha.year, c.fecha.month, c.fecha.day);
      porDia.putIfAbsent(d, () => []).add(c);
    }
    final esMesActual = _mes.year == _hoy.year && _mes.month == _hoy.month;
    final esHoy = _mismoDia(_dia, _hoy);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          if (!esMesActual || !esHoy)
            TextButton(onPressed: _irAHoy, child: const Text('Hoy')),
          const SizedBox(width: Espacio.sm),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agendaMesProvider(_mes)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espacio.pantalla,
            Espacio.sm,
            Espacio.pantalla,
            Espacio.xxl,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Espacio.sm,
                  Espacio.sm,
                  Espacio.sm,
                  Espacio.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CabeceraMes(
                      mes: _mes,
                      onAnterior: () => _cambiarMes(-1),
                      onSiguiente: () => _cambiarMes(1),
                    ),
                    const SizedBox(height: Espacio.sm),
                    _Mes(
                      mes: _mes,
                      hoy: _hoy,
                      seleccionado: _dia,
                      porDia: porDia,
                      onElegir: (d) => setState(() => _dia = d),
                    ),
                    if (controles.isLoading) ...[
                      const SizedBox(height: Espacio.sm),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            EncabezadoSeccion(_tituloDelDia(_dia, _hoy)),
            if (controles.hasError)
              VistaError(
                error: controles.error!,
                onReintentar: () => ref.invalidate(agendaMesProvider(_mes)),
              )
            else if (controles.isLoading && !controles.hasValue)
              const TarjetaEsqueleto()
            else
              _ListaDelDia(controles: porDia[_dia] ?? const [], hoy: _hoy),
          ],
        ),
      ),
    );
  }

  static String _tituloDelDia(DateTime dia, DateTime hoy) {
    final texto = DateFormat("EEEE d 'de' MMMM", 'es_PE').format(dia);
    final bonito = texto[0].toUpperCase() + texto.substring(1);
    return _mismoDia(dia, hoy) ? 'Hoy · $bonito' : bonito;
  }
}

bool _mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Noviembre 2026" con flechas para ir al mes anterior o al siguiente.
class _CabeceraMes extends StatelessWidget {
  const _CabeceraMes({
    required this.mes,
    required this.onAnterior,
    required this.onSiguiente,
  });

  final DateTime mes;
  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final nombre = DateFormat('MMMM y', 'es_PE').format(mes);
    return Row(
      children: [
        IconButton(
          onPressed: onAnterior,
          tooltip: 'Mes anterior',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                nombre[0].toUpperCase() + nombre.substring(1),
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onSiguiente,
          tooltip: 'Mes siguiente',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// La cuadrícula del mes, de lunes a domingo.
class _Mes extends StatelessWidget {
  const _Mes({
    required this.mes,
    required this.hoy,
    required this.seleccionado,
    required this.porDia,
    required this.onElegir,
  });

  final DateTime mes;
  final DateTime hoy;
  final DateTime seleccionado;
  final Map<DateTime, List<Control>> porDia;
  final ValueChanged<DateTime> onElegir;

  static const _inicialesSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final diasDelMes = DateTime(mes.year, mes.month + 1, 0).day;
    final vaciosAntes = DateTime(mes.year, mes.month).weekday - 1; // lunes = 0
    final celdas = <Widget>[
      for (var i = 0; i < vaciosAntes; i++) const SizedBox.shrink(),
      for (var d = 1; d <= diasDelMes; d++)
        _Dia(
          fecha: DateTime(mes.year, mes.month, d),
          hoy: hoy,
          seleccionado: _mismoDia(
            DateTime(mes.year, mes.month, d),
            seleccionado,
          ),
          controles: porDia[DateTime(mes.year, mes.month, d)] ?? const [],
          onTap: () => onElegir(DateTime(mes.year, mes.month, d)),
        ),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(const SizedBox.shrink());
    }

    return Column(
      children: [
        ExcludeSemantics(
          child: Row(
            children: [
              for (final inicial in _inicialesSemana)
                Expanded(
                  child: Center(
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        fontSize: TipoTam.etiqueta,
                        fontWeight: FontWeight.w700,
                        color: Tokens.textoSecundario,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.xs),
        for (var fila = 0; fila < celdas.length ~/ 7; fila++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: celdas[fila * 7 + col]),
            ],
          ),
      ],
    );
  }
}

/// Un día del calendario: el número y, si tiene controles, cuántos.
class _Dia extends StatelessWidget {
  const _Dia({
    required this.fecha,
    required this.hoy,
    required this.seleccionado,
    required this.controles,
    required this.onTap,
  });

  final DateTime fecha;
  final DateTime hoy;
  final bool seleccionado;
  final List<Control> controles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esHoy = _mismoDia(fecha, hoy);
    final cantidad = controles.length;
    final etiqueta = DateFormat("EEEE d 'de' MMMM", 'es_PE').format(fecha);
    final detalle = switch (cantidad) {
      0 => 'sin controles',
      1 => '1 control',
      _ => '$cantidad controles',
    };

    return Semantics(
      button: true,
      selected: seleccionado,
      label: '${esHoy ? 'Hoy, ' : ''}$etiqueta, $detalle',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: seleccionado ? Tokens.marcaSuave : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radios.control),
            side: esHoy
                ? const BorderSide(color: Tokens.marcaFuerte, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radios.control),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Espacio.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${fecha.day}',
                        style: TextStyle(
                          fontSize: TipoTam.cuerpo,
                          fontWeight: esHoy || seleccionado
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: esHoy ? Tokens.marcaFuerte : Tokens.texto,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Un punto por día con controles, con el número si son varios.
                    SizedBox(
                      height: 16,
                      child: cantidad == 0
                          ? null
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Tokens.marcaFuerte,
                                  borderRadius: BorderRadius.circular(
                                    Radios.pildora,
                                  ),
                                ),
                                child: Text(
                                  '$cantidad',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Tokens.textoSobreAccion,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Los controles del día elegido, en una tarjeta.
class _ListaDelDia extends StatelessWidget {
  const _ListaDelDia({required this.controles, required this.hoy});

  final List<Control> controles;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    if (controles.isEmpty) {
      return const EstadoVacio(
        icono: Icons.event_available_outlined,
        texto: 'No hay controles este día.',
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < controles.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _FilaControl(control: controles[i]),
          ],
        ],
      ),
    );
  }
}

class _FilaControl extends StatelessWidget {
  const _FilaControl({required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    final c = control;
    final hora = c.hora == null ? null : sinCortes(Fechas.hora(c.hora!));
    final detalle = hora == null
        ? c.tratamientoNombre
        : '${c.tratamientoNombre} · $hora';
    return InkWell(
      onTap: () => context.push(Rutas.paciente(c.pacienteId)),
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
                    Text(
                      c.paciente?.nombre ?? 'Paciente',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: const TextStyle(
                        fontSize: TipoTam.cuerpo,
                        color: Tokens.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: Espacio.xs),
                    chipDeControl(c),
                  ],
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
