import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/router/app_router.dart';
import 'package:gerenz_dent/core/widgets/pantalla_de_carga.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/auth/presentation/login_page.dart';

import '../helpers/fakes.dart';

void main() {
  Widget app(AlmacenSesion almacen) => ProviderScope(
    overrides: [almacenSesionProvider.overrideWithValue(almacen)],
    child: Consumer(
      builder: (context, ref, _) =>
          MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
    ),
  );

  /// Monta la app y espera a que el logo de la pantalla de carga se dibuje
  /// (desde ese momento cuentan los 2 s).
  Future<void> montarHastaVerLogo(WidgetTester tester, AlmacenSesion a) async {
    await tester.pumpWidget(app(a));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/carga-centro.png'),
        tester.element(find.byType(PantallaDeCarga)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('con la sesión ya guardada, la pantalla de carga se ve 2 s', (
    tester,
  ) async {
    await montarHastaVerLogo(tester, AlmacenSesionMemoria(sesionPrueba()));
    // La sesión se lee al instante, pero la pantalla de carga sigue.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(PantallaDeCarga), findsOneWidget);
  });

  testWidgets(
    'sin sesión, a los 2 s de verse el logo pasa al inicio de sesión',
    (tester) async {
      await montarHastaVerLogo(tester, AlmacenSesionMemoria());
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.byType(PantallaDeCarga), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.byType(PantallaDeCarga), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );

  testWidgets('si el logo nunca se dibuja, igual sigue a los 6 s', (
    tester,
  ) async {
    // Sin la imagen en caché: en la prueba, el logo no llega a dibujarse.
    imageCache
      ..clear()
      ..clearLiveImages();
    await tester.pumpWidget(app(AlmacenSesionMemoria()));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(PantallaDeCarga), findsOneWidget);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
