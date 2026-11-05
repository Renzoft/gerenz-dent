import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Componentes base del sistema v2 (docs/rediseno/02-sistema-de-diseno.md).
///
/// Regla: un estado nunca se comunica solo con color; siempre lleva ícono y
/// texto.

/// Evita que "p. m." o "a. m." se partan en dos líneas con letra grande.
String sinCortes(String texto) => texto
    .replaceAll(' p. m.', '${_nbsp}p.${_nbsp}m.')
    .replaceAll(' a. m.', '${_nbsp}a.${_nbsp}m.');

/// Espacio que no permite salto de línea (U+00A0).
final _nbsp = String.fromCharCode(0x00A0);

/// Pestaña cuyo texto se achica (en vez de cortarse) con letra muy grande.
class PestanaTexto extends StatelessWidget {
  const PestanaTexto(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(texto)),
    );
  }
}

/// Chip de estado: ícono + texto sobre el tono del estado (≥ 4.5:1).
class ChipEstado extends StatelessWidget {
  const ChipEstado({
    super.key,
    required this.tono,
    required this.icono,
    required this.texto,
  });

  final Tono tono;
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado: $texto',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Espacio.md,
          vertical: Espacio.xs + 2,
        ),
        decoration: BoxDecoration(
          color: tono.fondo,
          borderRadius: BorderRadius.circular(Radios.pildora),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18, color: tono.contenido),
            const SizedBox(width: Espacio.xs + 2),
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  color: tono.contenido,
                  fontSize: TipoTam.etiqueta,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso destacado (alergia, error de una sección).
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.tono,
    required this.icono,
    required this.texto,
    this.titulo,
  });

  final Tono tono;
  final IconData icono;
  final String texto;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: tono == Tono.peligro,
      child: Container(
        padding: const EdgeInsets.all(Espacio.md),
        decoration: BoxDecoration(
          color: tono.fondo,
          borderRadius: BorderRadius.circular(Radios.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: tono.contenido),
            const SizedBox(width: Espacio.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (titulo != null)
                      TextSpan(
                        text: '$titulo ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(text: texto),
                  ],
                ),
                style: TextStyle(
                  color: tono.contenido,
                  fontSize: TipoTam.cuerpo,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de un grupo de contenido, con una acción opcional a la derecha.
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion(this.titulo, {super.key, this.accion});

  final String titulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Espacio.xl, bottom: Espacio.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Estado vacío: qué pasa y qué hacer.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
  });

  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacio.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icono, color: Tokens.textoSecundario),
                ),
                const SizedBox(width: Espacio.md),
                Expanded(
                  child: Text(
                    texto,
                    style: const TextStyle(
                      fontSize: TipoTam.cuerpo,
                      color: Tokens.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
            if (accion != null) ...[
              const SizedBox(height: Espacio.lg),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque de carga con pulso suave. Sin animación si el sistema pide
/// reducir movimiento.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, this.alto = 16, this.ancho, this.radio = 8});

  final double alto;
  final double? ancho;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulso.value = 0.7;
      _pulso.stop();
    } else if (!_pulso.isAnimating) {
      _pulso.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulso,
      child: Container(
        height: widget.alto,
        width: widget.ancho,
        decoration: BoxDecoration(
          color: Primitivos.neutro200,
          borderRadius: BorderRadius.circular(widget.radio),
        ),
      ),
    );
  }
}

/// Tarjeta de carga con la forma aproximada del contenido.
class TarjetaEsqueleto extends StatelessWidget {
  const TarjetaEsqueleto({super.key});

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
              Esqueleto(alto: 20, ancho: 180),
              SizedBox(height: Espacio.md),
              Esqueleto(alto: 28, ancho: 110, radio: Radios.pildora),
              SizedBox(height: Espacio.lg),
              Esqueleto(alto: 52, radio: Radios.control),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opción de una [mostrarOpciones].
class Opcion<T> {
  const Opcion({
    required this.valor,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.peligrosa = false,
  });

  final T valor;
  final IconData icono;
  final String titulo;
  final String? detalle;
  final bool peligrosa;
}

/// Hoja inferior con opciones con nombre y explicación (en vez de un menú ⋮).
Future<T?> mostrarOpciones<T>(
  BuildContext context, {
  required String titulo,
  required List<Opcion<T>> opciones,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Espacio.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Espacio.xl,
              0,
              Espacio.xl,
              Espacio.sm,
            ),
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final o in opciones)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Espacio.xl,
              ),
              leading: Icon(
                o.icono,
                color: o.peligrosa ? Tokens.error : Tokens.textoSecundario,
              ),
              title: Text(
                o.titulo,
                style: TextStyle(
                  fontSize: TipoTam.subtitulo,
                  fontWeight: FontWeight.w600,
                  color: o.peligrosa ? Tokens.error : Tokens.texto,
                ),
              ),
              subtitle: o.detalle == null ? null : Text(o.detalle!),
              onTap: () => Navigator.of(context).pop(o.valor),
            ),
        ],
      ),
    ),
  );
}
