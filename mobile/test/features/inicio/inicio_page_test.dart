import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/inicio/data/salud_repository.dart';
import 'package:gerenz_dent/features/inicio/presentation/inicio_page.dart';
import 'package:mocktail/mocktail.dart';

class _SaludRepositoryFalso extends Mock implements SaludRepository {}

void main() {
  late _SaludRepositoryFalso repositorio;

  setUp(() => repositorio = _SaludRepositoryFalso());

  Future<void> montar(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [saludRepositoryProvider.overrideWithValue(repositorio)],
        child: MaterialApp(theme: AppTheme.claro, home: const InicioPage()),
      ),
    );
  }

  testWidgets('muestra "Conectando…" mientras espera al servidor', (
    tester,
  ) async {
    when(
      () => repositorio.servidorDisponible(),
    ).thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => true));

    await montar(tester);

    expect(find.text('Conectando con el consultorio…'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('muestra "Conectado" cuando la API responde UP', (tester) async {
    when(() => repositorio.servidorDisponible()).thenAnswer((_) async => true);

    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Conectado'), findsOneWidget);
    expect(find.text('Bienvenido, Dr. Marco Munayco'), findsOneWidget);
  });

  testWidgets('si falla, muestra error y "Reintentar" vuelve a consultar', (
    tester,
  ) async {
    var llamadas = 0;
    when(() => repositorio.servidorDisponible()).thenAnswer((_) async {
      llamadas++;
      if (llamadas == 1) throw Exception('sin conexión');
      return true;
    });

    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Conectado'), findsOneWidget);
    expect(llamadas, 2);
  });
}
