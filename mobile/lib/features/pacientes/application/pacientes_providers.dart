import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/pacientes_repository.dart';
import '../domain/paciente.dart';

/// Filtros de la lista de pacientes.
class FiltroPacientes {
  const FiltroPacientes({this.texto = '', this.archivados = false});

  final String texto;
  final bool archivados;

  FiltroPacientes copiar({String? texto, bool? archivados}) => FiltroPacientes(
    texto: texto ?? this.texto,
    archivados: archivados ?? this.archivados,
  );
}

class FiltroPacientesNotifier extends Notifier<FiltroPacientes> {
  @override
  FiltroPacientes build() => const FiltroPacientes();

  void buscar(String texto) => state = state.copiar(texto: texto);

  void verArchivados({required bool archivados}) =>
      state = state.copiar(archivados: archivados);
}

final filtroPacientesProvider =
    NotifierProvider<FiltroPacientesNotifier, FiltroPacientes>(
      FiltroPacientesNotifier.new,
    );

/// Lista visible: se recarga sola al cambiar el filtro. Soporta "cargar más".
class ListaPacientes {
  const ListaPacientes({
    required this.pacientes,
    required this.total,
    required this.paginaActual,
    required this.hayMas,
    this.cargandoMas = false,
  });

  final List<Paciente> pacientes;
  final int total;
  final int paginaActual;
  final bool hayMas;
  final bool cargandoMas;
}

class ListaPacientesNotifier extends AsyncNotifier<ListaPacientes> {
  @override
  Future<ListaPacientes> build() async {
    final filtro = ref.watch(filtroPacientesProvider);
    final pagina = await ref
        .read(pacientesRepositoryProvider)
        .listar(texto: filtro.texto, archivados: filtro.archivados);
    return ListaPacientes(
      pacientes: pagina.contenido,
      total: pagina.totalElementos,
      paginaActual: 0,
      hayMas: pagina.hayMas,
    );
  }

  Future<void> cargarMas() async {
    final actual = state.value;
    if (actual == null || !actual.hayMas || actual.cargandoMas) return;
    state = AsyncData(
      ListaPacientes(
        pacientes: actual.pacientes,
        total: actual.total,
        paginaActual: actual.paginaActual,
        hayMas: actual.hayMas,
        cargandoMas: true,
      ),
    );
    final filtro = ref.read(filtroPacientesProvider);
    final siguiente = await ref
        .read(pacientesRepositoryProvider)
        .listar(
          texto: filtro.texto,
          archivados: filtro.archivados,
          pagina: actual.paginaActual + 1,
        );
    state = AsyncData(
      ListaPacientes(
        pacientes: [...actual.pacientes, ...siguiente.contenido],
        total: siguiente.totalElementos,
        paginaActual: siguiente.pagina,
        hayMas: siguiente.hayMas,
      ),
    );
  }
}

final listaPacientesProvider =
    AsyncNotifierProvider<ListaPacientesNotifier, ListaPacientes>(
      ListaPacientesNotifier.new,
      retry: (intento, error) => null,
    );

/// Un paciente por id (ficha).
final pacienteProvider = FutureProvider.autoDispose.family<Paciente, String>(
  (ref, id) => ref.read(pacientesRepositoryProvider).obtener(id),
  retry: (intento, error) => null,
);

/// Invalida la lista y la ficha después de crear/editar/archivar.
void refrescarPacientes(WidgetRef ref, [String? id]) {
  ref.invalidate(listaPacientesProvider);
  if (id != null) ref.invalidate(pacienteProvider(id));
}
