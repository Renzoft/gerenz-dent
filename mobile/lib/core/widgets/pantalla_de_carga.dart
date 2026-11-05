import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Pantalla de carga al abrir la app: logo de cristal sobre luces celeste y
/// verde, con el logo y los textos centrados en la pantalla.
///
/// Sigue al fondo nativo (mismo celeste profundo), así que no hay salto de
/// color al pasar de Android a Flutter.
class PantallaDeCarga extends StatefulWidget {
  const PantallaDeCarga({super.key, this.alMostrarse});

  /// Se llama una vez, cuando el logo ya está dibujado en pantalla (desde ahí
  /// cuenta el tiempo mínimo que se ve).
  final VoidCallback? alMostrarse;

  /// Celeste profundo del ícono (también en android/.../values/colors.xml).
  static const fondo = Color(0xFF0A5676);

  @override
  State<PantallaDeCarga> createState() => _PantallaDeCargaState();
}

class _PantallaDeCargaState extends State<PantallaDeCarga> {
  var _avisado = false;

  void _avisarSiSeVe(int? cuadro) {
    if (_avisado || cuadro == null) return;
    _avisado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.alMostrarse?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    const fondo = PantallaDeCarga.fondo;
    final abajo = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: fondo,
      ),
      child: Scaffold(
        backgroundColor: fondo,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Luz celeste arriba a la izquierda y verde abajo a la derecha.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.65, -0.6),
                  radius: 0.8,
                  colors: [Color(0xF23BB5E8), Color(0x003BB5E8)],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.75, 0.65),
                  radius: 0.8,
                  colors: [Color(0xE622B573), Color(0x0022B573)],
                ),
              ),
            ),
            // Logo y textos en el centro exacto (la imagen ya trae el
            // nombre y "Consultorio odontológico").
            Center(
              child: Image.asset(
                'assets/branding/carga-centro.png',
                width: 256,
                semanticLabel: 'GERENZ DENT, consultorio odontológico',
                frameBuilder: (context, child, cuadro, sincrono) {
                  _avisarSiSeVe(cuadro);
                  return child;
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: abajo + Espacio.xxxl,
              child: Semantics(
                label: 'Abriendo GERENZ DENT',
                child: const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
