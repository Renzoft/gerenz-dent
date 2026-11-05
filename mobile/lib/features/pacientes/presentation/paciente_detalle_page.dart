import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../../controles/application/controles_providers.dart';
import '../../controles/presentation/agendar_control_sheet.dart';
import '../../controles/presentation/tarjeta_control.dart';
import '../../cuenta/application/cuenta_providers.dart';
import '../../cuenta/presentation/seccion_cuenta.dart';
import '../application/pacientes_providers.dart';
import '../data/pacientes_repository.dart';
import '../domain/formato_whatsapp.dart';
import '../domain/paciente.dart';

/// Ficha del paciente (HU-05), rediseño v2 (pantalla piloto).
///
/// Cabecera con lo esencial (nombre, WhatsApp, alergia, próximo control y
/// deuda) y el resto agrupado en tres pestañas: Controles · Pagos · Datos.
class PacienteDetallePage extends ConsumerStatefulWidget {
  const PacienteDetallePage({
    super.key,
    required this.pacienteId,
    this.abrirAgendar = false,
  });

  final String pacienteId;

  /// Al venir de "Nuevo paciente" se abre directamente "Agendar control".
  final bool abrirAgendar;

  @override
  ConsumerState<PacienteDetallePage> createState() =>
      _PacienteDetallePageState();
}

class _PacienteDetallePageState extends ConsumerState<PacienteDetallePage> {
  bool _agendarAbierto = false;

  String get pacienteId => widget.pacienteId;

  void _abrirAgendarSiCorresponde(BuildContext context, Paciente p) {
    if (!widget.abrirAgendar || _agendarAbierto || p.archivado) return;
    _agendarAbierto = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      mostrarAgendarControl(
        context,
        pacienteId: p.id,
        pacienteNombre: p.nombre,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final paciente = ref.watch(pacienteProvider(pacienteId));

    if (paciente.value case final p?) _abrirAgendarSiCorresponde(context, p);
    return Scaffold(
      backgroundColor: Tokens.fondo,
      appBar: AppBar(
        backgroundColor: Tokens.superficieMarca,
        title: const Text('Ficha'),
        actions: [
          if (paciente.value case final p?)
            IconButton(
              tooltip: 'Editar datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Rutas.pacienteEditar(p.id)),
            ),
        ],
      ),
      body: paciente.when(
        loading: () => const _FichaCargando(),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(pacienteProvider(pacienteId)),
        ),
        data: (p) => _Ficha(paciente: p),
      ),
    );
  }
}

enum _Pestana { controles, pagos, datos }

class _Ficha extends ConsumerStatefulWidget {
  const _Ficha({required this.paciente});

  final Paciente paciente;

  @override
  ConsumerState<_Ficha> createState() => _FichaState();
}

class _FichaState extends ConsumerState<_Ficha>
    with SingleTickerProviderStateMixin {
  late final TabController _pestanas = TabController(
    length: _Pestana.values.length,
    vsync: this,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _pestanas.dispose();
    super.dispose();
  }

  void _irA(_Pestana p) => _pestanas.animateTo(p.index);

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    final actual = _Pestana.values[_pestanas.index];

    return RefreshIndicator(
      onRefresh: () async => refrescarPacientes(ref, p.id),
      child: ListView(
        padding: const EdgeInsets.only(bottom: Espacio.xxxl),
        children: [
          _Cabecera(
            paciente: p,
            alTocarControl: () => _irA(_Pestana.controles),
            alTocarDeuda: () => _irA(_Pestana.pagos),
          ),
          ColoredBox(
            color: Tokens.superficieMarca,
            child: TabBar(
              controller: _pestanas,
              tabs: const [
                PestanaTexto('Controles'),
                PestanaTexto('Pagos'),
                PestanaTexto('Datos'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.pantalla),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Movimiento.normal,
              switchInCurve: Movimiento.curvaEntrar,
              child: KeyedSubtree(
                key: ValueKey(actual),
                child: switch (actual) {
                  _Pestana.controles => _PestanaControles(paciente: p),
                  _Pestana.pagos => Padding(
                    padding: const EdgeInsets.only(top: Espacio.xl),
                    child: SeccionCuenta(pacienteId: p.id),
                  ),
                  _Pestana.datos => _PestanaDatos(paciente: p),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cabecera
// ---------------------------------------------------------------------------

class _Cabecera extends ConsumerWidget {
  const _Cabecera({
    required this.paciente,
    required this.alTocarControl,
    required this.alTocarDeuda,
  });

  final Paciente paciente;
  final VoidCallback alTocarControl;
  final VoidCallback alTocarDeuda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paciente;
    final textos = Theme.of(context).textTheme;
    final controles = ref.watch(historialPacienteProvider(p.id)).value;
    final cuenta = ref.watch(cuentaPacienteProvider(p.id)).value;
    final proximo = (controles?.where((c) => c.esAbierto).toList() ?? [])
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return Container(
      color: Tokens.superficieMarca,
      padding: const EdgeInsets.fromLTRB(
        Espacio.pantalla,
        Espacio.sm,
        Espacio.pantalla,
        Espacio.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Tokens.marcaSuave,
                  foregroundColor: Primitivos.celeste800,
                  child: Text(
                    _iniciales(p.nombre),
                    style: const TextStyle(
                      fontFamily: Fuentes.titulos,
                      fontWeight: FontWeight.w700,
                      fontSize: TipoTam.subtitulo,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Espacio.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(p.nombre, style: textos.headlineMedium),
                    ),
                    const SizedBox(height: Espacio.xs),
                    Row(
                      children: [
                        const ExcludeSemantics(
                          child: Icon(
                            Icons.phone_android,
                            size: 20,
                            color: Tokens.textoSecundario,
                          ),
                        ),
                        const SizedBox(width: Espacio.xs),
                        // Un teléfono no se parte: con letra muy grande se
                        // achica un poco.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              telefonoSinCortes(
                                FormatoWhatsapp.mostrar(p.whatsapp),
                              ),
                              style: const TextStyle(
                                fontSize: TipoTam.cuerpo,
                                color: Tokens.textoSecundario,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.archivado) ...[
            const SizedBox(height: Espacio.md),
            const Align(
              alignment: Alignment.centerLeft,
              child: ChipEstado(
                tono: Tono.neutro,
                icono: Icons.archive_outlined,
                texto: 'Archivado',
              ),
            ),
          ],
          if (p.tieneAlergias) ...[
            const SizedBox(height: Espacio.md),
            Aviso(
              tono: Tono.peligro,
              icono: Icons.warning_amber_rounded,
              titulo: 'Alergia:',
              texto: p.alergias!,
            ),
          ],
          const SizedBox(height: Espacio.md),
          // Resumen de un vistazo; cada dato lleva a su pestaña.
          Wrap(
            spacing: Espacio.sm,
            runSpacing: Espacio.sm,
            children: [
              if (controles != null)
                _DatoRapido(
                  icono: Icons.event_outlined,
                  texto: proximo.isEmpty
                      ? 'Sin control agendado'
                      : sinCortes('Próximo: ${proximo.first.fechaTexto()}'),
                  onTap: alTocarControl,
                ),
              if (cuenta != null && cuenta.planes.isNotEmpty)
                _DatoRapido(
                  icono: cuenta.deuda > 0
                      ? Icons.payments_outlined
                      : Icons.check_circle_outline,
                  texto: cuenta.deuda > 0
                      ? 'Debe ${Moneda.formatear(cuenta.deuda)}'
                      : 'Al día en pagos',
                  onTap: alTocarDeuda,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    final letras = partes.take(2).map((x) => x.characters.first.toUpperCase());
    return letras.join();
  }
}

/// Dato de la cabecera que lleva a su pestaña (≥ 48 dp de alto).
class _DatoRapido extends StatelessWidget {
  const _DatoRapido({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Tokens.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radios.control),
        side: const BorderSide(color: Tokens.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radios.control),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacio.md,
              vertical: Espacio.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Icon(icono, size: 20, color: Tokens.marcaFuerte),
                ),
                const SizedBox(width: Espacio.sm),
                Flexible(
                  child: Text(
                    texto,
                    style: const TextStyle(
                      fontSize: TipoTam.cuerpo,
                      fontWeight: FontWeight.w600,
                      color: Tokens.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña Controles: próximos + historial (HU-05, HU-11 a HU-14)
// ---------------------------------------------------------------------------

class _PestanaControles extends ConsumerWidget {
  const _PestanaControles({required this.paciente});

  final Paciente paciente;

  void _agendar(BuildContext context) => mostrarAgendarControl(
    context,
    pacienteId: paciente.id,
    pacienteNombre: paciente.nombre,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controles = ref.watch(historialPacienteProvider(paciente.id));

    return controles.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(
        padding: EdgeInsets.only(top: Espacio.xl),
        child: TarjetaEsqueleto(),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(top: Espacio.xl),
        child: VistaError(
          error: e,
          onReintentar: () =>
              ref.invalidate(historialPacienteProvider(paciente.id)),
        ),
      ),
      data: (lista) {
        final abiertos = lista.where((c) => c.esAbierto).toList()
          ..sort((a, b) => a.fecha.compareTo(b.fecha));
        final cerrados = lista.where((c) => !c.esAbierto).toList();
        final puedeAgendar = !paciente.archivado;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoSeccion(
              abiertos.length > 1 ? 'Próximos controles' : 'Próximo control',
            ),
            if (abiertos.isEmpty)
              EstadoVacio(
                icono: Icons.event_available_outlined,
                texto: 'No tiene un control agendado.',
                accion: puedeAgendar
                    ? FilledButton.icon(
                        onPressed: () => _agendar(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Agendar control'),
                      )
                    : null,
              ),
            for (final (i, c) in abiertos.indexed) ...[
              TarjetaControl(
                control: c,
                pacienteNombre: paciente.nombre,
                destacada: i == 0,
              ),
              const SizedBox(height: Espacio.md),
            ],
            if (abiertos.isNotEmpty && puedeAgendar)
              OutlinedButton.icon(
                onPressed: () => _agendar(context),
                icon: const Icon(Icons.add),
                label: const Text('Agendar otro control'),
              ),
            if (cerrados.isNotEmpty) ...[
              const EncabezadoSeccion('Historial'),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cerrados.length; i++) ...[
                      if (i > 0) const Divider(),
                      FilaHistorial(control: cerrados[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Pestaña Datos
// ---------------------------------------------------------------------------

class _PestanaDatos extends ConsumerStatefulWidget {
  const _PestanaDatos({required this.paciente});

  final Paciente paciente;

  @override
  ConsumerState<_PestanaDatos> createState() => _PestanaDatosState();
}

class _PestanaDatosState extends ConsumerState<_PestanaDatos> {
  bool _procesando = false;

  Future<void> _cambiarArchivo() async {
    final p = widget.paciente;
    final archivar = !p.archivado;
    if (archivar) {
      final ok = await confirmar(
        context,
        titulo: 'Archivar paciente',
        mensaje:
            '${p.nombre} dejará de aparecer en la lista y en los recordatorios. '
            'Su información se conserva y puedes recuperarlo cuando quieras.',
        accion: 'Archivar',
      );
      if (!ok) return;
    }
    setState(() => _procesando = true);
    try {
      final repo = ref.read(pacientesRepositoryProvider);
      archivar ? await repo.archivar(p.id) : await repo.desarchivar(p.id);
      if (!mounted) return;
      refrescarPacientes(ref, p.id);
      mostrarMensaje(
        context,
        archivar ? 'Paciente archivado' : 'Paciente recuperado',
      );
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EncabezadoSeccion('Datos del paciente'),
        Card(
          child: Column(
            children: [
              _Dato(
                icono: Icons.cake_outlined,
                etiqueta: 'Edad',
                valor: p.edad == null ? 'Sin registrar' : '${p.edad} años',
              ),
              const Divider(),
              _Dato(
                icono: Icons.healing_outlined,
                etiqueta: 'Alergias',
                valor: p.alergias ?? 'Ninguna registrada',
              ),
              const Divider(),
              _Dato(
                icono: Icons.notes,
                etiqueta: 'Nota',
                valor: p.nota ?? 'Sin nota',
              ),
              const Divider(),
              _Dato(
                icono: p.consienteWhatsapp
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                etiqueta: 'Recordatorios por WhatsApp',
                valor: p.consienteWhatsapp ? 'Autorizados' : 'No autorizados',
              ),
            ],
          ),
        ),
        const SizedBox(height: Espacio.lg),
        OutlinedButton.icon(
          onPressed: () => context.push(Rutas.pacienteEditar(p.id)),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar datos'),
        ),
        const SizedBox(height: Espacio.sm),
        TextButton.icon(
          onPressed: _procesando ? null : _cambiarArchivo,
          style: TextButton.styleFrom(foregroundColor: Tokens.textoSecundario),
          icon: Icon(p.archivado ? Icons.unarchive : Icons.archive_outlined),
          label: Text(p.archivado ? 'Recuperar paciente' : 'Archivar paciente'),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListTile(
        leading: ExcludeSemantics(child: Icon(icono)),
        title: Text(
          etiqueta,
          style: const TextStyle(
            fontSize: TipoTam.etiqueta,
            color: Tokens.textoSecundario,
          ),
        ),
        subtitle: Text(
          valor,
          style: const TextStyle(
            fontSize: TipoTam.subtitulo,
            color: Tokens.texto,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Carga
// ---------------------------------------------------------------------------

class _FichaCargando extends StatelessWidget {
  const _FichaCargando();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          color: Tokens.superficieMarca,
          padding: const EdgeInsets.all(Espacio.pantalla),
          child: const Row(
            children: [
              Esqueleto(alto: 56, ancho: 56, radio: 28),
              SizedBox(width: Espacio.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Esqueleto(alto: 26, ancho: 200),
                    SizedBox(height: Espacio.sm),
                    Esqueleto(alto: 16, ancho: 140),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(Espacio.pantalla),
          child: TarjetaEsqueleto(),
        ),
      ],
    );
  }
}
