import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/estados.dart';
import '../application/pacientes_providers.dart';
import '../domain/formato_whatsapp.dart';
import '../domain/paciente.dart';

/// Lista y búsqueda de pacientes (HU-04).
class PacientesPage extends ConsumerStatefulWidget {
  const PacientesPage({super.key});

  @override
  ConsumerState<PacientesPage> createState() => _PacientesPageState();
}

class _PacientesPageState extends ConsumerState<PacientesPage> {
  final _busqueda = TextEditingController();
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    _busqueda.text = ref.read(filtroPacientesProvider).texto;
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  /// Espera a que el doctor deje de escribir para no consultar en cada letra.
  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(
      const Duration(milliseconds: 350),
      () => ref.read(filtroPacientesProvider.notifier).buscar(texto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(filtroPacientesProvider);
    final lista = ref.watch(listaPacientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Rutas.pacienteNuevo),
        icon: const Icon(Icons.person_add),
        label: const Text('Paciente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _busqueda,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o número',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busqueda.clear();
                          _alEscribir('');
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Archivados'),
                  selected: filtro.archivados,
                  onSelected: (v) => ref
                      .read(filtroPacientesProvider.notifier)
                      .verArchivados(archivados: v),
                ),
                const Spacer(),
                if (lista.value case final datos?)
                  Text(
                    '${datos.total} paciente${datos.total == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.grisTexto),
                  ),
              ],
            ),
          ),
          Expanded(
            child: lista.when(
              skipLoadingOnReload: true,
              loading: () => const VistaCargando(),
              error: (e, _) => VistaError(
                error: e,
                onReintentar: () => ref.invalidate(listaPacientesProvider),
              ),
              data: (datos) => RefreshIndicator(
                onRefresh: () => ref.refresh(listaPacientesProvider.future),
                child: datos.pacientes.isEmpty
                    ? _ListaVacia(filtro: filtro)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount:
                            datos.pacientes.length + (datos.hayMas ? 1 : 0),
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          if (i == datos.pacientes.length) {
                            return _BotonCargarMas(cargando: datos.cargandoMas);
                          }
                          return _FilaPaciente(paciente: datos.pacientes[i]);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPaciente extends StatelessWidget {
  const _FilaPaciente({required this.paciente});

  final Paciente paciente;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      leading: CircleAvatar(
        backgroundColor: AppColors.celesteFondo,
        foregroundColor: AppColors.verdeOscuro,
        child: Text(paciente.nombre.characters.first.toUpperCase()),
      ),
      title: Text(paciente.nombre, style: const TextStyle(fontSize: 18)),
      subtitle: Text(FormatoWhatsapp.mostrar(paciente.whatsapp)),
      trailing: paciente.tieneAlergias
          ? const Tooltip(
              message: 'Tiene alergias',
              child: Icon(Icons.warning_amber_rounded, color: AppColors.error),
            )
          : const Icon(Icons.chevron_right),
      onTap: () => context.push(Rutas.paciente(paciente.id)),
    );
  }
}

class _BotonCargarMas extends ConsumerWidget {
  const _BotonCargarMas({required this.cargando});

  final bool cargando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(
        onPressed: cargando
            ? null
            : () => ref.read(listaPacientesProvider.notifier).cargarMas(),
        child: Text(cargando ? 'Cargando…' : 'Ver más pacientes'),
      ),
    );
  }
}

class _ListaVacia extends StatelessWidget {
  const _ListaVacia({required this.filtro});

  final FiltroPacientes filtro;

  @override
  Widget build(BuildContext context) {
    final String mensaje;
    if (filtro.texto.trim().isNotEmpty) {
      mensaje = 'No hay pacientes que coincidan con "${filtro.texto.trim()}".';
    } else if (filtro.archivados) {
      mensaje = 'No hay pacientes archivados.';
    } else {
      mensaje =
          'Aún no hay pacientes.\nToca "Paciente" para registrar el primero.';
    }
    // ListView para que funcione "deslizar para actualizar".
    return ListView(
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.people_outline, size: 56, color: AppColors.grisTexto),
        const SizedBox(height: 12),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grisTexto, fontSize: 16),
        ),
      ],
    );
  }
}
