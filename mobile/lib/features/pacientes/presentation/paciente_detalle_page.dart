import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../application/pacientes_providers.dart';
import '../data/pacientes_repository.dart';
import '../domain/formato_whatsapp.dart';
import '../domain/paciente.dart';

/// Ficha del paciente (HU-05). El próximo control, el historial y la deuda
/// se agregan en las iteraciones 2 y 4.
class PacienteDetallePage extends ConsumerWidget {
  const PacienteDetallePage({super.key, required this.pacienteId});

  final String pacienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paciente = ref.watch(pacienteProvider(pacienteId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paciente'),
        actions: [
          if (paciente.value case final p?)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(Rutas.pacienteEditar(p.id)),
            ),
        ],
      ),
      body: paciente.when(
        loading: () => const VistaCargando(),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(pacienteProvider(pacienteId)),
        ),
        data: (p) => _Ficha(paciente: p),
      ),
    );
  }
}

class _Ficha extends ConsumerStatefulWidget {
  const _Ficha({required this.paciente});

  final Paciente paciente;

  @override
  ConsumerState<_Ficha> createState() => _FichaState();
}

class _FichaState extends ConsumerState<_Ficha> {
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
    final textos = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(p.nombre, style: textos.headlineSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.phone_android,
              size: 20,
              color: AppColors.grisTexto,
            ),
            const SizedBox(width: 6),
            Text(FormatoWhatsapp.mostrar(p.whatsapp), style: textos.bodyLarge),
          ],
        ),
        if (p.archivado) ...[
          const SizedBox(height: 12),
          const Chip(
            avatar: Icon(Icons.archive_outlined, size: 18),
            label: Text('Archivado'),
          ),
        ],
        if (p.tieneAlergias) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.error),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alergia: ${p.alergias}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              _Dato(
                icono: Icons.cake_outlined,
                etiqueta: 'Edad',
                valor: p.edad == null ? '—' : '${p.edad} años',
              ),
              _Dato(icono: Icons.notes, etiqueta: 'Nota', valor: p.nota ?? '—'),
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
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _procesando ? null : _cambiarArchivo,
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
    return ListTile(
      leading: Icon(icono, color: AppColors.verdeOscuro),
      title: Text(etiqueta, style: const TextStyle(color: AppColors.grisTexto)),
      subtitle: Text(
        valor,
        style: const TextStyle(fontSize: 17, color: AppColors.texto),
      ),
    );
  }
}
