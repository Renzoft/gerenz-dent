import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/avisos/avisos_diarios.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/application/auth_controller.dart';
import '../../controles/application/controles_providers.dart';
import '../../controles/domain/control.dart';
import '../../recordatorios/application/recordatorios_providers.dart';
import '../../recordatorios/domain/mensaje_recordatorio.dart';
import '../data/salud_repository.dart';

/// Inicio (v1.1): tarjetas en el orden en que el doctor las usa en el día.
///
/// 1. Recordatorios de mañana (la tarea diaria, con un botón grande).
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
    final estado = ref.watch(estadoServidorProvider);
    final usuario = ref.watch(authControllerProvider).value;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reintentarTodo(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _Encabezado(nombreCorto: usuario?.nombreCorto),
              const SizedBox(height: 20),
              // Solo se muestra mientras conecta o si falla.
              if (!(estado.value ?? false)) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: estado.when(
                      loading: () => const _EstadoConexion(
                        icono: SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        titulo: 'Conectando con el consultorio…',
                        detalle:
                            'La primera conexión del día puede tardar hasta 1 minuto.',
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
                const SizedBox(height: 16),
              ],
              const _TarjetaRecordatorios(),
              const SizedBox(height: 16),
              const _TarjetaHoy(),
              const SizedBox(height: 16),
              const _TarjetaNoVinieron(),
              const SizedBox(height: 16),
              const _TarjetaProximos(),
            ],
          ),
        ),
      ),
    );
  }

  static void _reintentarTodo(WidgetRef ref) {
    ref.invalidate(estadoServidorProvider);
    ref.invalidate(agendaSemanaProvider);
    refrescarRecordatorios(ref);
  }
}

// ---------------------------------------------------------------------------
// Encabezado
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nombreCorto == null
              ? saludo(DateTime.now())
              : '${saludo(DateTime.now())}, $nombreCorto',
          style: textos.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          hoy[0].toUpperCase() + hoy.substring(1),
          style: textos.bodyLarge?.copyWith(color: AppColors.grisTexto),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Base de las tarjetas
// ---------------------------------------------------------------------------

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.explicacion,
    required this.child,
    this.cantidad,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String explicacion;
  final int? cantidad;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      color: AppColors.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDCE7EC)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(icono, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: textos.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        explicacion,
                        style: textos.bodyMedium?.copyWith(
                          color: AppColors.grisTexto,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cantidad != null && cantidad! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$cantidad',
                      style: const TextStyle(
                        color: AppColors.blanco,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Carga / error / contenido de una tarjeta.
class _Contenido<T> extends StatelessWidget {
  const _Contenido({required this.valor, required this.construir});

  final AsyncValue<T> valor;
  final Widget Function(T) construir;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          ApiError.desde(e).mensaje,
          style: const TextStyle(color: AppColors.error),
        ),
      ),
      data: construir,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icono, color: AppColors.verde, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

/// Fila de paciente: nombre grande, detalle y una acción a la derecha.
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(Rutas.paciente(pacienteId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    detalle,
                    style: const TextStyle(color: AppColors.grisTexto),
                  ),
                ],
              ),
            ),
            accion ??
                const Icon(Icons.chevron_right, color: AppColors.grisTexto),
          ],
        ),
      ),
    );
  }
}

class _Enviado extends StatelessWidget {
  const _Enviado();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: AppColors.verde, size: 20),
        SizedBox(width: 4),
        Text(
          'Enviado',
          style: TextStyle(
            color: AppColors.verdeOscuro,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

String _dias(int n) => n == 1 ? 'hace 1 día' : 'hace $n días';

String _conHora(String tratamiento, TimeOfDay? hora) =>
    hora == null ? tratamiento : '$tratamiento · ${Fechas.hora(hora)}';

// ---------------------------------------------------------------------------
// 1. Recordatorios de mañana
// ---------------------------------------------------------------------------

class _TarjetaRecordatorios extends ConsumerWidget {
  const _TarjetaRecordatorios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manana = ref.watch(recordatoriosMananaProvider);
    final fecha = Fechas.larga(Fechas.hoy().add(const Duration(days: 1)));
    final porEnviar = manana.value?.where((m) => m.porEnviar).length ?? 0;

    return _Tarjeta(
      icono: Icons.send_rounded,
      color: AppColors.verdeBoton,
      titulo: 'Recordatorios de mañana',
      explicacion: 'Para los citados el $fecha',
      cantidad: porEnviar,
      child: _Contenido<List<MensajeRecordatorio>>(
        valor: manana,
        construir: (lista) {
          if (lista.isEmpty) {
            return const _Vacio(
              'Mañana no tienes pacientes citados.',
              icono: Icons.event_available,
            );
          }
          final enviables = lista.where((m) => m.sePuedeEnviar).toList();
          final enviados = enviables.where((m) => m.enviado).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enviables.isNotEmpty) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: enviados / enviables.length,
                    minHeight: 8,
                    color: AppColors.verde,
                    backgroundColor: AppColors.celesteFondo,
                  ),
                ),
                const SizedBox(height: 8),
                if (porEnviar == 0)
                  const _Vacio('¡Listo! Ya les recordaste a todos.')
                else
                  Text(
                    'Enviados $enviados de ${enviables.length}',
                    key: const Key('avance-recordatorios'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.grisTexto,
                    ),
                  ),
              ],
              const SizedBox(height: 4),
              for (final m in lista) _FilaRecordatorio(mensaje: m),
              if (porEnviar > 0) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('enviar-recordatorios'),
                  onPressed: () => enviarTodos(context, ref, lista),
                  icon: const Icon(Icons.send),
                  label: Text(
                    porEnviar == 1
                        ? 'Enviar recordatorio'
                        : 'Enviar recordatorios ($porEnviar)',
                  ),
                ),
              ],
            ],
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
      accion = const Text(
        'Sin WhatsApp',
        style: TextStyle(color: AppColors.grisTexto),
      );
    } else if (m.enviado) {
      accion = const _Enviado();
    } else {
      accion = TextButton(
        onPressed: () => _enviarUno(context, ref, m),
        child: const Text('Enviar'),
      );
    }
    return _FilaPaciente(
      nombre: m.pacienteNombre,
      detalle: _conHora(m.tratamiento, m.hora),
      pacienteId: m.pacienteId,
      accion: accion,
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

class _TarjetaHoy extends ConsumerWidget {
  const _TarjetaHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaSemanaProvider);
    final hoy = Fechas.hoy();
    final deHoy = agenda.value
        ?.where((c) => DateUtils.isSameDay(c.fecha, hoy))
        .toList();

    return _Tarjeta(
      icono: Icons.today,
      color: AppColors.celeste,
      titulo: 'Hoy vienen',
      explicacion: 'Al atenderlos, márcalos como "Asistió" en su ficha',
      cantidad: deHoy?.length,
      child: _Contenido<List<Control>>(
        valor: agenda,
        construir: (_) => deHoy!.isEmpty
            ? const _Vacio(
                'Hoy no hay pacientes citados.',
                icono: Icons.event_available,
              )
            : Column(
                children: [
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

class _TarjetaNoVinieron extends ConsumerWidget {
  const _TarjetaNoVinieron();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguimientos = ref.watch(seguimientosProvider);
    return _Tarjeta(
      icono: Icons.person_search,
      color: AppColors.error,
      titulo: 'No vinieron',
      explicacion: 'Ya pasó su fecha. Escríbeles para que vuelvan',
      cantidad: seguimientos.value?.length,
      child: _Contenido<List<MensajeRecordatorio>>(
        valor: seguimientos,
        construir: (lista) => lista.isEmpty
            ? const _Vacio('Todos vinieron a su control.')
            : Column(
                children: [
                  for (final m in lista)
                    _FilaPaciente(
                      nombre: m.pacienteNombre,
                      detalle: '${m.tratamiento} · ${_dias(m.diasAtraso)}',
                      pacienteId: m.pacienteId,
                      accion: !m.sePuedeEnviar
                          ? const Text(
                              'Sin WhatsApp',
                              style: TextStyle(color: AppColors.grisTexto),
                            )
                          : m.enviado
                          ? const _Enviado()
                          : TextButton(
                              onPressed: () => _enviarUno(context, ref, m),
                              child: const Text('Escribirle'),
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

class _TarjetaProximos extends ConsumerWidget {
  const _TarjetaProximos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaSemanaProvider);
    final hoy = Fechas.hoy();
    final proximos =
        agenda.value?.where((c) => c.fecha.isAfter(hoy)).toList() ?? [];
    final textos = Theme.of(context).textTheme;

    return Card(
      color: AppColors.blanco,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFDCE7EC)),
      ),
      child: ExpansionTile(
        key: const Key('proximos-dias'),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.grisTexto.withValues(alpha: 0.12),
          child: const Icon(Icons.date_range, color: AppColors.grisTexto),
        ),
        title: Text(
          'Próximos días (${proximos.length})',
          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Citas de esta semana'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (proximos.isEmpty)
            const _Vacio(
              'No hay más citas esta semana.',
              icono: Icons.event_available,
            ),
          for (final c in proximos)
            _FilaPaciente(
              nombre: c.paciente?.nombre ?? '',
              detalle: '${c.tratamientoNombre} · ${c.fechaTexto()}',
              pacienteId: c.pacienteId,
            ),
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.titleMedium),
              if (detalle != null) ...[
                const SizedBox(height: 4),
                Text(
                  detalle!,
                  style: textos.bodyMedium?.copyWith(
                    color: AppColors.grisTexto,
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
          icono: Icon(Icons.cloud_off, color: AppColors.error, size: 32),
          titulo: 'No se pudo conectar',
          detalle: 'Revisa tu internet e inténtalo de nuevo.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onReintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
