import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
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
    setState(() {}); // muestra u oculta el botón "Limpiar"
  }

  @override
  Widget build(BuildContext context) {
    final filtro = ref.watch(filtroPacientesProvider);
    final lista = ref.watch(listaPacientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pacientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Rutas.pacienteNuevo),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo paciente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacio.pantalla,
              Espacio.xs,
              Espacio.pantalla,
              Espacio.md,
            ),
            child: TextField(
              controller: _busqueda,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Buscar paciente',
                hintText: 'Nombre o número',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _busqueda.clear();
                          _alEscribir('');
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espacio.pantalla),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Espacio.md,
                runSpacing: Espacio.sm,
                children: [
                  FilterChip(
                    label: const Text('Archivados'),
                    avatar: filtro.archivados
                        ? null
                        : const Icon(Icons.archive_outlined, size: 18),
                    selected: filtro.archivados,
                    onSelected: (v) => ref
                        .read(filtroPacientesProvider.notifier)
                        .verArchivados(archivados: v),
                  ),
                  if (lista.value case final datos?)
                    Text(
                      '${datos.total} paciente${datos.total == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: TipoTam.cuerpo,
                        color: Tokens.textoSecundario,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Espacio.sm),
          Expanded(
            child: lista.when(
              skipLoadingOnReload: true,
              loading: () => const _ListaCargando(),
              error: (e, _) => VistaError(
                error: e,
                onReintentar: () => ref.invalidate(listaPacientesProvider),
              ),
              data: (datos) => RefreshIndicator(
                onRefresh: () => ref.refresh(listaPacientesProvider.future),
                child: datos.pacientes.isEmpty
                    ? _ListaVacia(filtro: filtro)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          Espacio.pantalla,
                          0,
                          Espacio.pantalla,
                          96,
                        ),
                        itemCount:
                            datos.pacientes.length + (datos.hayMas ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == datos.pacientes.length) {
                            return _BotonCargarMas(cargando: datos.cargandoMas);
                          }
                          return _FilaPaciente(
                            paciente: datos.pacientes[i],
                            primera: i == 0,
                            ultima:
                                i == datos.pacientes.length - 1 &&
                                !datos.hayMas,
                          );
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

/// Fila de la lista. Las filas forman una sola tarjeta (bordes redondeados
/// solo arriba de la primera y abajo de la última).
class _FilaPaciente extends StatelessWidget {
  const _FilaPaciente({
    required this.paciente,
    required this.primera,
    required this.ultima,
  });

  final Paciente paciente;
  final bool primera;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    const radio = Radius.circular(Radios.tarjeta);
    final forma = BorderRadius.vertical(
      top: primera ? radio : Radius.zero,
      bottom: ultima ? radio : Radius.zero,
    );
    return Container(
      decoration: BoxDecoration(
        color: Tokens.superficie,
        borderRadius: forma,
        border: Border(
          top: primera
              ? const BorderSide(color: Tokens.borde)
              : BorderSide.none,
          left: const BorderSide(color: Tokens.borde),
          right: const BorderSide(color: Tokens.borde),
          bottom: const BorderSide(color: Tokens.borde),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: forma,
          onTap: () => context.push(Rutas.paciente(paciente.id)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Espacio.lg,
                vertical: Espacio.md,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Tokens.marcaSuave,
                      foregroundColor: Primitivos.celeste800,
                      child: Text(
                        _iniciales(paciente.nombre),
                        style: const TextStyle(
                          fontFamily: Fuentes.titulos,
                          fontWeight: FontWeight.w700,
                          fontSize: TipoTam.cuerpo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Espacio.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          paciente.nombre,
                          style: const TextStyle(
                            fontSize: TipoTam.subtitulo,
                            fontWeight: FontWeight.w600,
                            color: Tokens.texto,
                          ),
                        ),
                        // Un teléfono no se parte: con letra muy grande se achica un poco.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            telefonoSinCortes(
                              FormatoWhatsapp.mostrar(paciente.whatsapp),
                            ),
                            style: const TextStyle(
                              fontSize: TipoTam.cuerpo,
                              color: Tokens.textoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (paciente.tieneAlergias)
                    const Tooltip(
                      message: 'Tiene alergias',
                      child: Padding(
                        padding: EdgeInsets.only(left: Espacio.sm),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Tokens.error,
                          semanticLabel: 'Tiene alergias',
                        ),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(left: Espacio.xs),
                    child: Icon(
                      Icons.chevron_right,
                      color: Tokens.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    return partes
        .take(2)
        .where((p) => p.isNotEmpty)
        .map((p) => p.characters.first.toUpperCase())
        .join();
  }
}

class _BotonCargarMas extends ConsumerWidget {
  const _BotonCargarMas({required this.cargando});

  final bool cargando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.lg),
      child: OutlinedButton(
        onPressed: cargando
            ? null
            : () => ref.read(listaPacientesProvider.notifier).cargarMas(),
        child: Text(cargando ? 'Cargando…' : 'Ver más pacientes'),
      ),
    );
  }
}

class _ListaCargando extends StatelessWidget {
  const _ListaCargando();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando pacientes',
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Espacio.pantalla),
        children: [
          for (var i = 0; i < 5; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Espacio.md),
              child: Row(
                children: [
                  Esqueleto(alto: 44, ancho: 44, radio: 22),
                  SizedBox(width: Espacio.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Esqueleto(alto: 18, ancho: 180),
                        SizedBox(height: Espacio.sm),
                        Esqueleto(alto: 14, ancho: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
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
          'Aún no hay pacientes.\nToca "Nuevo paciente" para registrar el primero.';
    }
    // ListView para que funcione "deslizar para actualizar".
    return ListView(
      padding: const EdgeInsets.all(Espacio.pantalla),
      children: [EstadoVacio(icono: Icons.people_outline, texto: mensaje)],
    );
  }
}
