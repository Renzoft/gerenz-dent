import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/moneda.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../data/tratamientos_repository.dart';
import '../domain/tratamiento.dart';

/// Catálogo de tratamientos editable (HU-10): precios, intervalos y altas.
class CatalogoPage extends ConsumerWidget {
  const CatalogoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoCompletoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de tratamientos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Agregar tratamiento'),
      ),
      body: catalogo.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Espacio.pantalla),
          child: Column(children: [TarjetaEsqueleto()]),
        ),
        error: (e, _) => VistaError(
          error: e,
          onReintentar: () => ref.invalidate(catalogoCompletoProvider),
        ),
        data: (lista) => ListView(
          padding: const EdgeInsets.fromLTRB(
            Espacio.pantalla,
            Espacio.xs,
            Espacio.pantalla,
            96,
          ),
          children: [
            const Aviso(
              tono: Tono.marca,
              icono: Icons.info_outline,
              texto:
                  'Los cambios de precio se aplican a los tratamientos que '
                  'empiecen desde ahora; las deudas ya registradas no cambian.',
            ),
            const SizedBox(height: Espacio.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < lista.length; i++) ...[
                    if (i > 0) const Divider(),
                    _FilaTratamiento(
                      tratamiento: lista[i],
                      resumen: _resumen(lista[i]),
                      onEditar: () => _editar(context, ref, lista[i]),
                      onActivo: (v) =>
                          _cambiarActivo(context, ref, lista[i], v),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _resumen(Tratamiento t) {
    final precio = t.precioBase == null ? '—' : Moneda.formatear(t.precioBase!);
    final cobro = switch (t.tipoPrecio) {
      TipoPrecio.fijo => precio,
      TipoPrecio.porPieza => '$precio por pieza',
      TipoPrecio.inicialMasMensual =>
        '$precio + ${t.precioMensual == null ? '—' : Moneda.formatear(t.precioMensual!)} por control',
    };
    final control = t.intervaloControlDias == null
        ? ''
        : ' · control cada ${t.intervaloControlDias} días'
              '${t.edadMaximaControl == null ? '' : ' (hasta ${t.edadMaximaControl} años)'}';
    return '$cobro$control${t.activo ? '' : ' · Inactivo'}';
  }

  Future<void> _cambiarActivo(
    BuildContext context,
    WidgetRef ref,
    Tratamiento t,
    bool activo,
  ) async {
    try {
      await ref
          .read(tratamientosRepositoryProvider)
          .cambiarActivo(t.id, activo: activo);
      _refrescar(ref);
      if (context.mounted) {
        mostrarMensaje(
          context,
          activo
              ? '${t.nombre} vuelve a estar disponible'
              : '${t.nombre} ya no se ofrecerá al agendar',
        );
      }
    } on ApiError catch (e) {
      if (context.mounted) mostrarMensaje(context, e.mensaje);
    }
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    Tratamiento? t,
  ) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FormularioTratamiento(existente: t),
    );
    if (guardado ?? false) {
      _refrescar(ref);
      if (context.mounted) mostrarMensaje(context, 'Catálogo actualizado');
    }
  }

  static void _refrescar(WidgetRef ref) {
    ref.invalidate(catalogoCompletoProvider);
    ref.invalidate(catalogoProvider);
  }
}

class FormularioTratamiento extends ConsumerStatefulWidget {
  const FormularioTratamiento({super.key, this.existente});

  final Tratamiento? existente;

  @override
  ConsumerState<FormularioTratamiento> createState() =>
      _FormularioTratamientoState();
}

class _FormularioTratamientoState extends ConsumerState<FormularioTratamiento> {
  late final _nombre = TextEditingController(text: widget.existente?.nombre);
  late TipoPrecio _tipo = widget.existente?.tipoPrecio ?? TipoPrecio.fijo;
  late final _precio = TextEditingController(
    text: widget.existente?.precioBase?.toStringAsFixed(2),
  );
  late final _mensual = TextEditingController(
    text: widget.existente?.precioMensual?.toStringAsFixed(2),
  );
  late final _intervalo = TextEditingController(
    text: widget.existente?.intervaloControlDias?.toString(),
  );
  late final _edad = TextEditingController(
    text: widget.existente?.edadMaximaControl?.toString(),
  );
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombre, _precio, _mensual, _intervalo, _edad]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().length < 2) {
      setState(() => _error = 'Ingresa el nombre');
      return;
    }
    final mensual = _tipo == TipoPrecio.inicialMasMensual
        ? Moneda.leer(_mensual.text)
        : null;
    if (_tipo == TipoPrecio.inicialMasMensual && mensual == null) {
      setState(() => _error = 'Indica la cuota mensual');
      return;
    }
    final intervalo = int.tryParse(_intervalo.text.trim());
    final datos = DatosTratamiento(
      nombre: _nombre.text.trim(),
      tipoPrecio: _tipo,
      precioBase: Moneda.leer(_precio.text),
      precioMensual: mensual,
      intervaloControlDias: intervalo,
      edadMaximaControl: intervalo == null
          ? null
          : int.tryParse(_edad.text.trim()),
    );
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref
          .read(tratamientosRepositoryProvider)
          .guardar(datos, id: widget.existente?.id);
      if (mounted) Navigator.of(context).pop(true);
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
    final textos = Theme.of(context).textTheme;
    final etiquetaPrecio = switch (_tipo) {
      TipoPrecio.fijo => 'Precio',
      TipoPrecio.porPieza => 'Precio por pieza',
      TipoPrecio.inicialMasMensual => 'Pago inicial',
    };
    return Padding(
      padding: EdgeInsets.only(
        left: Espacio.xl,
        right: Espacio.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Espacio.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existente == null
                  ? 'Nuevo tratamiento'
                  : 'Editar tratamiento',
              style: textos.titleLarge,
            ),
            const SizedBox(height: Espacio.xl),
            TextField(
              key: const Key('nombre-tratamiento'),
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 16),
            Text('¿Cómo se cobra?', style: textos.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TipoPrecio>(
              segments: [
                for (final t in TipoPrecio.values)
                  ButtonSegment(value: t, label: Text(t.etiqueta)),
              ],
              selected: {_tipo},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('precio-base'),
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: etiquetaPrecio,
                prefixText: 'S/ ',
              ),
            ),
            if (_tipo == TipoPrecio.inicialMasMensual) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('precio-mensual'),
                controller: _mensual,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cuota por control',
                  helperText: 'Se cobra cada vez que el paciente asiste',
                  prefixText: 'S/ ',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Próximo control (opcional)', style: textos.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('intervalo'),
                    controller: _intervalo,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Sugerir cada',
                      suffixText: 'días',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _edad,
                    enabled: _intervalo.text.trim().isNotEmpty,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Solo hasta',
                      suffixText: 'años',
                      helperText: 'Vacío: todas las edades',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Aviso(
                key: const Key('catalogo-error'),
                tono: Tono.peligro,
                icono: Icons.error_outline,
                texto: _error!,
              ),
              const SizedBox(height: Espacio.md),
            ],
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.check),
              label: Text(_guardando ? 'Guardando…' : 'Guardar tratamiento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaTratamiento extends StatelessWidget {
  const _FilaTratamiento({
    required this.tratamiento,
    required this.resumen,
    required this.onEditar,
    required this.onActivo,
  });

  final Tratamiento tratamiento;
  final String resumen;
  final VoidCallback onEditar;
  final ValueChanged<bool> onActivo;

  @override
  Widget build(BuildContext context) {
    final t = tratamiento;
    return InkWell(
      onTap: onEditar,
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
                    t.nombre,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: t.activo ? Tokens.texto : Tokens.textoSecundario,
                      decoration: t.activo ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resumen,
                    style: const TextStyle(
                      fontSize: TipoTam.cuerpo,
                      color: Tokens.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: t.activo
                  ? '${t.nombre}: se ofrece al agendar'
                  : '${t.nombre}: no se ofrece al agendar',
              child: Switch(value: t.activo, onChanged: onActivo),
            ),
          ],
        ),
      ),
    );
  }
}
