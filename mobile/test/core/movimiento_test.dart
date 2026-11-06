import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/core/theme/tokens.dart';
import 'package:gerenz_dent/core/ui/componentes.dart';

void main() {
  Future<AnimationStyle> estilo(
    WidgetTester tester, {
    required bool sinAnimaciones,
  }) async {
    late AnimationStyle resultado;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: sinAnimaciones),
        child: Builder(
          builder: (context) {
            resultado = estiloDePlegable(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return resultado;
  }

  testWidgets('los plegables abren rápido con salida suave (no easeIn)', (
    tester,
  ) async {
    final e = await estilo(tester, sinAnimaciones: false);
    expect(e.duration, Movimiento.normal);
    expect(e.curve, Movimiento.curvaEntrar);
    expect(e.curve, isNot(Curves.easeIn));
  });

  testWidgets('con "Quitar animaciones" los plegables no se animan', (
    tester,
  ) async {
    final e = await estilo(tester, sinAnimaciones: true);
    expect(e, AnimationStyle.noAnimation);
  });

  test('los toques usan el ripple clásico, no InkSparkle', () {
    expect(AppTheme.claro.splashFactory, InkRipple.splashFactory);
  });
}
