import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

/// Inicio (P1): recordar para mañana, vencidos y próximos 7 días.
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

  /// Reprograma el aviso diario con la cantidad de mensajes que faltan (HU-15).
  Future<void> _reprogramarAvisos(List<MensajeRecordatorio> manana) async {
    try {
      // Puede llegar antes que la sesión restaurada: se espera a que cargue.
      final usuario = await ref.read(authControllerProvider.future);
      if (usuario == null) return;
      await ref
          .read(servicioAvisosProvider)
          .programar(
            hora: usuario.horaNotificacion,
            pendientesHoy: manana.where((m) => m.porEnviar).length,
          );
    } catch (_) {
      // Sin permiso de notificaciones la app sigue funcionando.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordatoriosMananaProvider, (_, siguiente) {
      if (siguiente.value case final lista?) _reprogramarAvisos(lista);
    });
    final estado = ref.watch(estadoServidorProvider);
    final nombre = ref.watch(authControllerProvider).value?.nombre;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _reintentarTodo(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/branding/icono-app.svg',
                    height: 44,
                    semanticsLabel: 'GERENZ DENT',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      nombre == null ? 'Bienvenido' : 'Bienvenido, $nombre',
                      style: textos.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const _SeccionManana(),
              const SizedBox(height: 24),
              const _SeccionSeguimientos(),
              const SizedBox(height: 24),
              const _SeccionProximos(),
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

/// "Recordar para mañana" con Enviar y "Enviar todos uno por uno" (HU-16).
class _SeccionManana extends ConsumerWidget {
  const _SeccionManana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manana = ref.watch(recordatoriosMananaProvider);
    final lista = manana.value ?? const <MensajeRecordatorio>[];
    final porEnviar = lista.where((m) => m.porEnviar).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          manana.hasValue
              ? 'Recordar para mañana (${lista.length})'
              : 'Recordar para mañana',
        ),
        _Contenido<MensajeRecordatorio>(
          valor: manana,
          vacio: 'No hay controles para mañana.',
          construir: (lista) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final m in lista) _FilaMensaje(mensaje: m),
              if (porEnviar > 1) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => enviarTodos(context, ref, lista),
                  icon: const Icon(Icons.send),
                  label: Text('Enviar todos uno por uno ($porEnviar)'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Controles vencidos con su mensaje de seguimiento (HU-18).
class _SeccionSeguimientos extends ConsumerWidget {
  const _SeccionSeguimientos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seguimientos = ref.watch(seguimientosProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          seguimientos.hasValue
              ? 'Vencidos (${seguimientos.value!.length})'
              : 'Vencidos',
          color: AppColors.error,
        ),
        _Contenido<MensajeRecordatorio>(
          valor: seguimientos,
          vacio: 'No hay controles vencidos.',
          construir: (lista) => Column(
            children: [for (final m in lista) _FilaMensaje(mensaje: m)],
          ),
        ),
      ],
    );
  }
}

class _SeccionProximos extends ConsumerWidget {
  const _SeccionProximos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaSemanaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          agenda.hasValue
              ? 'Próximos 7 días (${agenda.value!.length})'
              : 'Próximos 7 días',
        ),
        _Contenido<Control>(
          valor: agenda,
          vacio: 'No hay controles en los próximos 7 días.',
          construir: (lista) => Column(
            children: [for (final c in lista) _FilaAgenda(control: c)],
          ),
        ),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

/// Carga / error / vacío / contenido de una sección.
class _Contenido<T> extends StatelessWidget {
  const _Contenido({
    required this.valor,
    required this.vacio,
    required this.construir,
  });

  final AsyncValue<List<T>> valor;
  final String vacio;
  final Widget Function(List<T>) construir;

  @override
  Widget build(BuildContext context) {
    return valor.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text(
        ApiError.desde(e).mensaje,
        style: const TextStyle(color: AppColors.error),
      ),
      data: (lista) => lista.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                vacio,
                style: const TextStyle(color: AppColors.grisTexto),
              ),
            )
          : construir(lista),
    );
  }
}

class _FilaMensaje extends ConsumerWidget {
  const _FilaMensaje({required this.mensaje});

  final MensajeRecordatorio mensaje;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = mensaje;
    final esSeguimiento = m.tipo == TipoRecordatorio.seguimiento;
    final dias = m.diasAtraso == 1 ? 'día' : 'días';
    final hora = m.hora == null ? '' : ' · ${Fechas.hora(m.hora!)}';
    final detalle = esSeguimiento
        ? '${m.tratamiento} · hace ${m.diasAtraso} $dias'
        : '${m.tratamiento}$hora';

    final Widget accion;
    if (!m.sePuedeEnviar) {
      accion = const Text(
        'No autoriza\nWhatsApp',
        textAlign: TextAlign.end,
        style: TextStyle(color: AppColors.grisTexto, fontSize: 13),
      );
    } else if (m.enviado) {
      accion = TextButton.icon(
        onPressed: () => _enviar(context, ref),
        icon: const Icon(Icons.check_circle, color: AppColors.verde),
        label: const Text('Enviado'),
      );
    } else {
      accion = FilledButton(
        // El tema usa ancho completo; en una fila de lista debe ser compacto.
        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: () => _enviar(context, ref),
        child: Text(esSeguimiento ? 'Seguimiento' : 'Enviar'),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 64,
      title: Text(m.pacienteNombre, style: const TextStyle(fontSize: 17)),
      subtitle: Text(detalle),
      trailing: accion,
      onTap: () => context.push(Rutas.paciente(m.pacienteId)),
    );
  }

  Future<void> _enviar(BuildContext context, WidgetRef ref) async {
    final r = await enviarRecordatorio(context, ref, mensaje);
    refrescarRecordatorios(ref);
    if (r == ResultadoEnvio.enviado && context.mounted) {
      mostrarMensaje(context, 'Recordatorio registrado');
    }
  }
}

class _FilaAgenda extends StatelessWidget {
  const _FilaAgenda({required this.control});

  final Control control;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 60,
      title: Text(
        control.paciente?.nombre ?? '',
        style: const TextStyle(fontSize: 17),
      ),
      subtitle: Text('${control.tratamientoNombre} · ${control.fechaTexto()}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(Rutas.paciente(control.pacienteId)),
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
