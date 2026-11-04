import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/network/api_error.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/auth/application/auth_controller.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/auth/data/auth_repository.dart';
import 'package:gerenz_dent/features/auth/presentation/login_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late AuthRepositoryFalso repositorio;
  late AlmacenSesionMemoria almacen;
  late ProviderContainer contenedor;

  setUp(() {
    repositorio = AuthRepositoryFalso();
    almacen = AlmacenSesionMemoria();
  });

  Future<void> montar(WidgetTester tester) async {
    contenedor = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repositorio),
        almacenSesionProvider.overrideWithValue(almacen),
      ],
    );
    addTearDown(contenedor.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: contenedor,
        child: MaterialApp(theme: AppTheme.claro, home: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

  testWidgets('valida los campos vacíos sin llamar a la API', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    verifyNever(() => repositorio.login(any(), any()));
  });

  testWidgets('con credenciales correctas guarda la sesión', (tester) async {
    when(
      () => repositorio.login('doctor@gerenzdent.test', 'clave-123'),
    ).thenAnswer((_) async => sesionPrueba());
    await montar(tester);

    await tester.enterText(campo('Correo'), 'doctor@gerenzdent.test');
    await tester.enterText(campo('Contraseña'), 'clave-123');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(almacen.sesion?.accessToken, 'access-1');
    expect(
      contenedor.read(authControllerProvider).value?.nombre,
      'Dr. Marco Munayco',
    );
  });

  testWidgets('muestra el mensaje de la API si falla', (tester) async {
    when(() => repositorio.login(any(), any())).thenThrow(
      const ApiError(mensaje: 'Correo o contraseña incorrectos.', estado: 401),
    );
    await montar(tester);

    await tester.enterText(campo('Correo'), 'doctor@gerenzdent.test');
    await tester.enterText(campo('Contraseña'), 'errada');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(almacen.sesion, isNull);
  });

  testWidgets('prefiere el error por campo al mensaje genérico', (
    tester,
  ) async {
    when(() => repositorio.login(any(), any())).thenThrow(
      const ApiError(
        mensaje: 'Revisa los campos marcados.',
        estado: 400,
        errores: {'email': 'Correo no válido'},
      ),
    );
    await montar(tester);

    await tester.enterText(campo('Correo'), 'doctor@x');
    await tester.enterText(campo('Contraseña'), 'clave');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Correo no válido'), findsOneWidget);
    expect(find.text('Revisa los campos marcados.'), findsNothing);
  });
}
