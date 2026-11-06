import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contactos/selector_contactos.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui/componentes.dart';
import '../../../core/widgets/estados.dart';
import '../application/pacientes_providers.dart';
import '../data/pacientes_repository.dart';
import '../domain/formato_whatsapp.dart';
import '../domain/paciente.dart';

/// Crear o editar un paciente (HU-02, HU-03, HU-06).
/// Solo nombre y WhatsApp son obligatorios; el resto va en "Más datos".
class PacienteFormPage extends ConsumerWidget {
  const PacienteFormPage({super.key, this.pacienteId});

  /// `null` = paciente nuevo.
  final String? pacienteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = pacienteId;
    if (id == null) return const _Formulario();

    final paciente = ref.watch(pacienteProvider(id));
    return paciente.when(
      loading: () => Scaffold(appBar: AppBar(), body: const VistaCargando()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: VistaError(
          error: e,
          onReintentar: () => ref.invalidate(pacienteProvider(id)),
        ),
      ),
      data: (p) => _Formulario(existente: p),
    );
  }
}

class _Formulario extends ConsumerStatefulWidget {
  const _Formulario({this.existente});

  final Paciente? existente;

  @override
  ConsumerState<_Formulario> createState() => _FormularioState();
}

class _FormularioState extends ConsumerState<_Formulario> {
  final _formulario = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.existente?.nombre);
  late final _whatsapp = TextEditingController(
    text: widget.existente == null
        ? null
        : FormatoWhatsapp.mostrar(widget.existente!.whatsapp),
  );
  late final _edad = TextEditingController(
    text: widget.existente?.edad?.toString(),
  );
  late final _alergias = TextEditingController(
    text: widget.existente?.alergias,
  );
  late final _nota = TextEditingController(text: widget.existente?.nota);
  late bool _consiente = widget.existente?.consienteWhatsapp ?? true;
  late final bool _masDatosAbierto =
      widget.existente != null &&
      (widget.existente!.edad != null ||
          widget.existente!.tieneAlergias ||
          widget.existente!.nota != null);

  bool _guardando = false;
  Map<String, String> _erroresServidor = const {};

  bool get _esNuevo => widget.existente == null;

  @override
  void dispose() {
    for (final c in [_nombre, _whatsapp, _edad, _alergias, _nota]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opcional(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// HU-07: trae el número (y el nombre, si aún no se escribió) de la agenda.
  Future<void> _importarContacto() async {
    try {
      final contacto = await ref
          .read(selectorContactosProvider)
          .elegirTelefono();
      if (contacto == null || !mounted) return;
      setState(() {
        if (contacto.telefono != null) _whatsapp.text = contacto.telefono!;
        final nombre = contacto.nombre?.trim();
        if (_nombre.text.trim().isEmpty &&
            nombre != null &&
            nombre.isNotEmpty) {
          _nombre.text = nombre;
        }
      });
      _formulario.currentState?.validate();
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo abrir los contactos.');
    }
  }

  Future<void> _guardar() async {
    setState(() => _erroresServidor = const {});
    if (!_formulario.currentState!.validate()) return;

    final datos = DatosPaciente(
      nombre: _nombre.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      edad: int.tryParse(_edad.text.trim()),
      alergias: _opcional(_alergias),
      nota: _opcional(_nota),
      consienteWhatsapp: _consiente,
    );

    setState(() => _guardando = true);
    final repositorio = ref.read(pacientesRepositoryProvider);
    try {
      final guardado = _esNuevo
          ? await repositorio.crear(datos)
          : await repositorio.actualizar(widget.existente!.id, datos);
      if (!mounted) return;
      refrescarPacientes(ref, guardado.id);
      mostrarMensaje(
        context,
        _esNuevo ? 'Paciente registrado' : 'Cambios guardados',
      );
      if (_esNuevo) {
        // Registrar paciente + próximo control en un solo flujo (≤ 30 s).
        context.pushReplacement(Rutas.paciente(guardado.id, agendar: true));
      } else {
        context.pop();
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.esConflicto && e.datos['pacienteExistenteId'] != null) {
        await _avisarDuplicado(e);
      } else if (e.errores.isNotEmpty) {
        setState(() => _erroresServidor = e.errores);
        _formulario.currentState!.validate();
      } else {
        mostrarMensaje(context, e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _avisarDuplicado(ApiError e) async {
    final verlo = await confirmar(
      context,
      titulo: 'Número ya registrado',
      mensaje: e.mensaje,
      accion: 'Ver paciente',
    );
    if (verlo && mounted) {
      context.pushReplacement(
        Rutas.paciente(e.datos['pacienteExistenteId'] as String),
      );
    }
  }

  /// Combina la validación local con el error que devolvió la API.
  String? Function(String?) _validador(
    String campo, [
    String? Function(String?)? local,
  ]) {
    return (valor) => local?.call(valor) ?? _erroresServidor[campo];
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_esNuevo ? 'Nuevo paciente' : 'Editar paciente'),
      ),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(Espacio.pantalla),
          children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              validator: _validador('nombre', (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Ingresa el nombre';
                if (t.length < 2) return 'Mínimo 2 caracteres';
                return null;
              }),
            ),
            const SizedBox(height: Espacio.sm),
            TextFormField(
              controller: _whatsapp,
              decoration: InputDecoration(
                labelText: 'WhatsApp',
                hintText: '987 654 321',
                helperText: 'Celular de 9 dígitos',
                prefixIcon: const Icon(Icons.phone_android),
                suffixIcon: IconButton(
                  tooltip: 'Elegir de mis contactos',
                  icon: const Icon(Icons.contacts_outlined),
                  onPressed: _importarContacto,
                ),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
              ],
              textInputAction: TextInputAction.next,
              validator: _validador('whatsapp', FormatoWhatsapp.validar),
            ),
            const SizedBox(height: Espacio.lg),
            Card(
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Espacio.lg,
                ),
                title: const Text('Autoriza recordatorios por WhatsApp'),
                subtitle: const Text(
                  'Si lo desactivas, no aparecerá para enviarle mensajes',
                ),
                value: _consiente,
                onChanged: (v) => setState(() => _consiente = v),
              ),
            ),
            const SizedBox(height: Espacio.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                expansionAnimationStyle: estiloDePlegable(context),
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: Espacio.lg),
                initiallyExpanded: _masDatosAbierto,
                leading: const Icon(Icons.badge_outlined),
                title: Text('Más datos (opcional)', style: textos.titleSmall),
                subtitle: const Text('Edad, alergias, nota'),
                childrenPadding: const EdgeInsets.fromLTRB(
                  Espacio.lg,
                  Espacio.sm,
                  Espacio.lg,
                  Espacio.lg,
                ),
                children: [
                  TextFormField(
                    controller: _edad,
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      suffixText: 'años',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: _validador('edad', (v) {
                      final edad = int.tryParse((v ?? '').trim());
                      if (edad != null && edad > 120) {
                        return 'Escribe una edad de 0 a 120';
                      }
                      return null;
                    }),
                  ),
                  const SizedBox(height: Espacio.lg),
                  TextFormField(
                    controller: _alergias,
                    decoration: const InputDecoration(
                      labelText: 'Alergias',
                      hintText: 'Ej.: penicilina, látex',
                    ),
                    maxLength: 200,
                    validator: _validador('alergias'),
                  ),
                  const SizedBox(height: Espacio.sm),
                  TextFormField(
                    controller: _nota,
                    decoration: const InputDecoration(labelText: 'Nota'),
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 300,
                    maxLines: 3,
                    validator: _validador('nota'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Espacio.xl),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              // Ícono fijo: el diálogo de "número ya registrado" puede
              // aparecer mientras guarda.
              icon: Icon(_guardando ? Icons.hourglass_top : Icons.check),
              label: Text(_guardando ? 'Guardando…' : 'Guardar paciente'),
            ),
          ],
        ),
      ),
    );
  }
}
