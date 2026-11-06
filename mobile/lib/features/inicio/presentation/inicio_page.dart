import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/avisos/avisos_diarios.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/application/auth_controller.dart';
import '../../controles/application/controles_providers.dart';
import '../../controles/domain/control.dart';
import '../../controles/presentation/cuando_vuelve.dart';
import '../../recordatorios/application/recordatorios_providers.dart';
import '../../recordatorios/domain/mensaje_recordatorio.dart';
import '../data/salud_repository.dart';

/// Inicio (v2): la tarea del día primero y el resto como listas livianas.
///
/// 1. Recordatorios de mañana: la tarea diaria, con el botón principal.
/// 2. Hoy vienen.
/// 3. No vinieron (seguimiento).
/// 4. Próximos días (plegado).
class InicioPage extends ConsumerStatefulWidget {
  const InicioPage({super.key});

  @override
  ConsumerState<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends ConsumerState<InicioPage> {
  @override
  void initState() {
    super.initState();
    // Pide permiso de notificaciones una vez (Android 13+).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(servicioAvisosProvider).pedirPermiso();
      } catch (_) {}
    });
  }

  /// Reprograma el aviso diario con la hora del doctor y lo que falta enviar
  /// (HU-15). Se llama cuando cambia la lista de mañana o la hora del aviso.
  Future<void> _reprogramarAvisos() async {
    try {
      final usuario = await ref.read(authControllerProvider.future);
      if (usuario == null) return;
      final manana = ref.read(recordatoriosMananaProvider).value;
      await ref
          .read(servicioAvisosProvider)
          .programar(
            hora: usuario.horaNotificacion,
            pendientesHoy: manana?.where((m) => m.porEnviar).length,
          );
    } catch (e) {
      // Sin permiso de notificaciones la app sigue funcionando.
      debugPrint('No se pudo programar el aviso diario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordatoriosMananaProvider, (_, siguiente) {
      if (siguiente.hasValue) _reprogramarAvisos();
    });
    ref.listen(
      authControllerProvider.select((u) => u.value?.horaNotificacion),
      (anterior, siguiente) {
        if (anterior != null && anterior != siguiente) _reprogramarAvisos();
      },
    );
    // Cuando el servidor termina de despertar, las secciones que fallaron
    // mientras tanto se recargan solas: no hace falta cerrar la app.
    ref.listen(estadoServidorProvider, (anterior, siguiente) {
      if (siguiente.value == true && anterior?.value != true) {
        _recargarLasQueFallaron(ref);
      }
    });
    final estado = ref.watch(estadoServidorProvider);
    final usuario = ref.watch(authControllerProvider).value;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Tokens.fondo,
        // La franja de la barra de estado lleva el color de la cabecera.
        body: ColoredBox(
          color: Tokens.superficieMarca,
          child: SafeArea(
            bottom: false,
            child: ColoredBox(
              color: Tokens.fondo,
              child: RefreshIndicator(
                onRefresh: () async => _reintentarTodo(ref),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: Espacio.xxl),
                  children: [
                    _Encabezado(nombreCorto: usuario?.nombreCorto),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espacio.pantalla,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Solo se muestra mientras conecta o si falla.
                          if (!(estado.value ?? false)) ...[
                            const SizedBox(height: Espacio.lg),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(Espacio.lg),
                                child: estado.when(
                                  loading: () => const _EstadoConexion(
                                    icono: SizedBox.square(
                                      dimension: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color: Tokens.marcaFuerte,
                                      ),
                                    ),
                                    titulo: 'Conectando con el consultorio…',
                                    detalle:
                                        'Si la app no se usó en un rato, puede tardar hasta 1 minuto. '
                                        'No hace falta cerrarla: todo se carga solo.',
                                  ),
                                  data: (_) => _ErrorConexion(
                                    onReintentar: () => _reintentarTodo(ref),
                                  ),
                                  error: (_, _) => _ErrorConexion(
                                    onReintentar: () => _reintentarTodo(ref),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const _SeccionRecordatorios(),
                          const _SeccionHoy(),
                          const _SeccionNoVinieron(),
                          const SizedBox(height: Espacio.xl),
                          const _Proximos(),
                        ],
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

  static void _recargarLasQueFallaron(WidgetRef ref) {
    if (ref.read(recordatoriosMananaProvider).hasError ||
        ref.read(seguimientosProvider).hasError) {
      refrescarRecordatorios(ref); // también recarga la agenda
    } else if (ref.read(agendaSemanaProvider).hasError) {
      ref.invalidate(agendaSemanaProvider);
    }
  }

  static void _reintentarTodo(WidgetRef ref) {
    ref.invalidate(estadoServidorProvider);
    ref.invalidate(agendaSemanaProvider);
    refrescarRecordatorios(ref);
  }
}

// ---------------------------------------------------------------------------
// Encabezado: saludo, fecha y acceso a la búsqueda de pacientes
// ---------------------------------------------------------------------------

class _Encabezado extends StatelessWidget {
  const _Encabezado({this.nombreCorto});

  final String? nombreCorto;

  static String saludo(DateTime ahora) {
    if (ahora.hour < 12) return 'Buenos días';
    if (ahora.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoy = Fechas.larga(DateTime.now());
    return Container(
      color: Tokens.superficieMarca,
      padding: const EdgeInsets.all(
        Espacio.pantalla,
      ).copyWith(top: Espacio.xl, bottom: Espacio.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/branding/logo-marca.png',
              height: 32,
              semanticLabel: 'GERENZ DENT',
            ),
          ),
          const SizedBox(height: Espacio.lg),
          // Siempre en una sola línea ("Buenas noches, Dr. Marco" incluido):
          // si no cabe, se achica un poco en vez de partirse.
          Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nombreCorto == null
                    ? saludo(DateTime.now())
                    : '${saludo(DateTime.now())}, $nombreCorto',
                maxLines: 1,
                softWrap: false,
                style: textos.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: Espacio.xs),
          Text(
            hoy[0].toUpperCase() + hoy.substring(1),
            style: const TextStyle(
              fontSize: TipoTam.cuerpo,
              color: Tokens.textoSecundario,
            ),
          ),
          const SizedBox(height: Espacio.lg),
          // Lo más usado a un toque: buscar un paciente.
          Material(
            color: Tokens.superficie,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radios.control),
              side: const BorderSide(color: Tokens.bordeControl),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radios.control),
              onTap: () => context.go(Rutas.pacientes),
              child: Semantics(
                button: true,
                label: 'Buscar paciente',
                excludeSemantics: true,
                child: const Padding(
                  padding: EdgeInsets.all(Espacio.lg),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Tokens.textoSecundario),
                      SizedBox(width: Espacio.md),
                      Expanded(
                        child: Text(
                          'Buscar paciente',
                          style: TextStyle(
                            fontSize: TipoTam.cuerpo,
                            color: Tokens.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas comunes
// ---------------------------------------------------------------------------

/// Título de sección con su explicación corta y un contador.
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.explicacion,
    required this.child,
    this.cantidad,
  });

  final String titulo;
  final String explicacion;
  final int? cantidad;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final n = cantidad ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoSeccion(
          titulo,
          accion: n == 0
              ? null
              : Semantics(
                  label: n == 1 ? '1 paciente' : '$n pacientes',
                  excludeSemantics: true,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Espacio.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.marcaSuave,
                      borderRadius: BorderRadius.circular(Radios.pildora),
                    ),
                    child: Text(
                      '$n',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: TipoTam.cuerpo,
                        fontWeight: FontWeight.w700,
                        color: Primitivos.celeste800,
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: Espacio.md),
          child: Text(
            explicacion,
            style: const TextStyle(
              fontSize: TipoTam.cuerpo,
              color: Tokens.textoSecundario,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Carga (esqueleto) / error con "Reintentar" / contenido de una sección.
class _Contenido<T> extends StatelessWidget {
  const _Contenido({
    required this.valor,
    required this.construir,
    required this.onReintentar,
  });

  final AsyncValue<T> valor;
  final Widget Function(T) construir;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _FilasCargando(),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Aviso(
            tono: Tono.peligro,
            icono: Icons.cloud_off,
            texto: ApiError.desde(e).mensaje,
          ),
          const SizedBox(height: Espacio.sm),
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
      data: construir,
    );
  }
}

class _FilasCargando extends StatelessWidget {
  const _FilasCargando();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: const Card(
        child: Padding(
          padding: EdgeInsets.all(Espacio.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Esqueleto(alto: 18, ancho: 160),
              SizedBox(height: Espacio.sm),
              Esqueleto(alto: 14, ancho: 220),
              SizedBox(height: Espacio.lg),
              Esqueleto(alto: 18, ancho: 140),
              SizedBox(height: Espacio.sm),
              Esqueleto(alto: 14, ancho: 200),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje tranquilo cuando no hay nada que hacer.
class _Vacio extends StatelessWidget {
  const _Vacio(this.texto, {this.icono = Icons.check_circle_outline});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.lg),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icono, color: Primitivos.verde700, size: 24),
            ),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: TipoTam.cuerpo),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filas dentro de una tarjeta, separadas por divisores.
class _Lista extends StatelessWidget {
  const _Lista({required this.filas});

  final List<Widget> filas;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0) const Divider(indent: Espacio.lg),
            filas[i],
          ],
        ],
      ),
    );
  }
}

/// Fila de paciente: nombre, detalle y una acción a la derecha. Tocar la fila
/// abre la ficha.
class _FilaPaciente extends StatelessWidget {
  const _FilaPaciente({
    required this.nombre,
    required this.detalle,
    required this.pacienteId,
    this.accion,
  });

  final String nombre;
  final String detalle;
  final String pacienteId;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final datos = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 2),
        Text(
          sinCortes(detalle),
          style: const TextStyle(
            fontSize: TipoTam.cuerpo,
            color: Tokens.textoSecundario,
          ),
        ),
      ],
    );
    const relleno = EdgeInsets.fromLTRB(
      Espacio.lg,
      Espacio.md,
      Espacio.sm,
      Espacio.md,
    );
    // Con letra muy grande la acción no cabe al lado: va debajo.
    if (accion != null && letraGrande(context)) {
      return InkWell(
        onTap: () => context.push(Rutas.paciente(pacienteId)),
        child: Padding(
          padding: relleno,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              datos,
              const SizedBox(height: Espacio.xs),
              accion!,
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => context.push(Rutas.paciente(pacienteId)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: relleno,
          child: Row(
            children: [
              Expanded(child: datos),
              const SizedBox(width: Espacio.sm),
              accion ??
                  const Padding(
                    padding: EdgeInsets.only(right: Espacio.sm),
                    child: Icon(
                      Icons.chevron_right,
                      color: Tokens.textoSecundario,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

const _enviado = ChipEstado(
  tono: Tono.exito,
  icono: Icons.check_circle_outline,
  texto: 'Enviado',
);

const _sinWhatsapp = ChipEstado(
  tono: Tono.neutro,
  icono: Icons.phone_disabled_outlined,
  texto: 'Sin WhatsApp',
);

String _dias(int n) => switch (n) {
  0 => 'hoy',
  1 => 'hace 1 día',
  _ => 'hace $n días',
};

String _conHora(String tratamiento, TimeOfDay? hora) =>
    hora == null ? tratamiento : '$tratamiento · ${Fechas.hora(hora)}';

// ---------------------------------------------------------------------------
// 1. Recordatorios de mañana (la tarea principal)
// ---------------------------------------------------------------------------

class _SeccionRecordatorios extends ConsumerWidget {
  const _SeccionRecordatorios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manana = ref.watch(recordatoriosMananaProvider);
    final fecha = Fechas.larga(Fechas.hoy().add(const Duration(days: 1)));
    final porEnviar = manana.value?.where((m) => m.porEnviar).length ?? 0;

    return _Seccion(
      titulo: 'Recordatorios de mañana',
      explicacion: 'Para los citados el $fecha',
      cantidad: porEnviar,
      child: _Contenido<List<MensajeRecordatorio>>(
        valor: manana,
        onReintentar: () => refrescarRecordatorios(ref),
        construir: (lista) {
          if (lista.isEmpty) {
            return const _Vacio(
              'Mañana no tienes pacientes citados.',
              icono: Icons.event_available,
            );
          }
          final enviables = lista.where((m) => m.sePuedeEnviar).toList();
          final enviados = enviables.where((m) => m.enviado).length;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (enviables.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Espacio.lg,
                      Espacio.lg,
                      Espacio.lg,
                      Espacio.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: 'Enviados $enviados de ${enviables.length}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Radios.pildora),
                            child: LinearProgressIndicator(
                              value: enviados / enviables.length,
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: Espacio.sm),
                        if (porEnviar == 0)
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Primitivos.verde700,
                              ),
                              SizedBox(width: Espacio.sm),
                              Expanded(
                                child: Text(
                                  '¡Listo! Ya les recordaste a todos.',
                                  style: TextStyle(
                                    fontSize: TipoTam.cuerpo,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Enviados $enviados de ${enviables.length}',
                            key: const Key('avance-recordatorios'),
                            style: const TextStyle(
                              fontSize: TipoTam.cuerpo,
                              color: Tokens.textoSecundario,
                            ),
                          ),
                      ],
                    ),
                  ),
                for (var i = 0; i < lista.length; i++) ...[
                  if (i > 0) const Divider(indent: Espacio.lg),
                  _FilaRecordatorio(mensaje: lista[i]),
                ],
                if (porEnviar > 0)
                  Padding(
                    padding: const EdgeInsets.all(Espacio.lg),
                    child: FilledButton.icon(
                      key: const Key('enviar-recordatorios'),
                      onPressed: () => enviarTodos(context, ref, lista),
                      icon: const Icon(Icons.send),
                      label: Text(
                        porEnviar == 1
                            ? 'Enviar recordatorio'
                            : 'Enviar recordatorios ($porEnviar)',
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilaRecordatorio extends ConsumerWidget {
  const _FilaRecordatorio({required this.mensaje});

  final MensajeRecordatorio mensaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = mensaje;
    final Widget accion;
    if (!m.sePuedeEnviar) {
      accion = _sinWhatsapp;
    } else if (m.enviado) {
      accion = _enviado;
    } else {
      accion = TextButton.icon(
        onPressed: () => _enviarUno(context, ref, m),
        icon: const Icon(Icons.send, size: 20),
        label: const Text('Enviar'),
      );
    }
    return _FilaPaciente(
      nombre: m.pacienteNombre,
      detalle: _conHora(m.tratamiento, m.hora),
      pacienteId: m.pacienteId,
      accion: Padding(
        padding: const EdgeInsets.only(right: Espacio.sm),
        child: accion,
      ),
    );
  }
}

Future<void> _enviarUno(
  BuildContext context,
  WidgetRef ref,
  MensajeRecordatorio m,
) async {
  final r = await enviarRecordatorio(context, ref, m);
  refrescarRecordatorios(ref);
  if (r == ResultadoEnvio.enviado && context.mounted) {
    mostrarMensaje(context, 'Mensaje registrado');
  }
}

// ---------------------------------------------------------------------------
// 2. Hoy vienen
// ---------------------------------------------------------------------------

class _SeccionHoy extends ConsumerWidget {
  const _SeccionHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaSemanaProvider);
    final hoy = Fechas.hoy();
    final deHoy = agenda.value
        ?.where((c) => DateUtils.isSameDay(c.fecha, hoy))
        .toList();

    return _Seccion(
      titulo: 'Hoy vienen',
      explicacion: 'Al atenderlos, márcalos como "Asistió" en su ficha',
      cantidad: deHoy?.length,
      child: _Contenido<List<Control>>(
        valor: agenda,
        onReintentar: () => ref.invalidate(agendaSemanaProvider),
        construir: (_) => deHoy!.isEmpty
            ? const _Vacio(
                'Hoy no hay pacientes citados.',
                icono: Icons.event_available,
              )
            : _Lista(
                filas: [
                  for (final c in deHoy)
                    _FilaPaciente(
                      nombre: c.paciente?.nombre ?? '',
                      detalle: _conHora(c.tratamientoNombre, c.hora),
                      pacienteId: c.pacienteId,
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. No vinieron
// ---------------------------------------------------------------------------

class _SeccionNoVinieron extends ConsumerWidget {
  const _SeccionNoVinieron();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguimientos = ref.watch(seguimientosProvider);
    return _Seccion(
      titulo: 'No vinieron',
      explicacion: 'Ya pasó su fecha. Escríbeles para que vuelvan',
      cantidad: seguimientos.value?.length,
      child: _Contenido<List<MensajeRecordatorio>>(
        valor: seguimientos,
        onReintentar: () => refrescarRecordatorios(ref),
        construir: (lista) => lista.isEmpty
            ? const _Vacio('Todos vinieron a su control.')
            : _Lista(
                filas: [
                  for (final m in lista)
                    _FilaPaciente(
                      nombre: m.pacienteNombre,
                      // "No vino" (marcado) o vencido (nadie lo marcó).
                      detalle: [
                        m.tratamiento,
                        m.estado == EstadoControl.noAsistio
                            ? 'no vino ${_dias(m.diasAtraso)}'
                            : _dias(m.diasAtraso),
                        if (m.enviado) 'mensaje enviado',
                      ].join(' · '),
                      pacienteId: m.pacienteId,
                      accion: Padding(
                        padding: const EdgeInsets.only(right: Espacio.sm),
                        // Ya se le escribió (o no tiene WhatsApp): cuando
                        // responda, se le pone la fecha desde aquí mismo.
                        child: m.enviado || !m.sePuedeEnviar
                            ? TextButton.icon(
                                onPressed: () => ponerNuevaFecha(
                                  context,
                                  ref,
                                  controlId: m.controlId,
                                  pacienteId: m.pacienteId,
                                ),
                                icon: const Icon(
                                  Icons.event_available,
                                  size: 20,
                                ),
                                label: const Text('Poner fecha'),
                              )
                            : TextButton.icon(
                                onPressed: () => _enviarUno(context, ref, m),
                                icon: const Icon(Icons.chat_outlined, size: 20),
                                label: const Text('Escribirle'),
                              ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Próximos días (plegado)
// ---------------------------------------------------------------------------

class _Proximos extends ConsumerWidget {
  const _Proximos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaSemanaProvider);
    final hoy = Fechas.hoy();
    final proximos =
        agenda.value?.where((c) => c.fecha.isAfter(hoy)).toList() ?? [];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('proximos-dias'),
        expansionAnimationStyle: estiloDePlegable(context),
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        leading: const Icon(Icons.date_range, color: Tokens.marcaFuerte),
        title: Text(
          'Próximos días (${proximos.length})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: const Text('Citas de esta semana'),
        children: [
          if (proximos.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                Espacio.lg,
                0,
                Espacio.lg,
                Espacio.lg,
              ),
              child: Text(
                'No hay más citas esta semana.',
                style: TextStyle(
                  fontSize: TipoTam.cuerpo,
                  color: Tokens.textoSecundario,
                ),
              ),
            ),
          for (final c in proximos) ...[
            const Divider(indent: Espacio.lg),
            _FilaPaciente(
              nombre: c.paciente?.nombre ?? '',
              detalle: '${c.tratamientoNombre} · ${c.fechaTexto()}',
              pacienteId: c.pacienteId,
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoConexion extends StatelessWidget {
  const _EstadoConexion({
    required this.icono,
    required this.titulo,
    this.detalle,
  });

  final Widget icono;
  final String titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        icono,
        const SizedBox(width: Espacio.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.titleSmall),
              if (detalle != null) ...[
                const SizedBox(height: Espacio.xs),
                Text(
                  detalle!,
                  style: const TextStyle(
                    fontSize: TipoTam.cuerpo,
                    color: Tokens.textoSecundario,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorConexion extends StatelessWidget {
  const _ErrorConexion({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EstadoConexion(
          icono: Icon(Icons.cloud_off, color: Tokens.error, size: 32),
          titulo: 'No se pudo conectar',
          detalle: 'Revisa tu internet e inténtalo de nuevo.',
        ),
        const SizedBox(height: Espacio.lg),
        FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
