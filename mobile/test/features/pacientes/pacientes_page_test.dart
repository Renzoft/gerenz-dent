import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/presentation/pacientes_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late PacientesRepositoryFalso repositorio;

  setUp(() => repositorio = PacientesRepositoryFalso());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pacientesRepositoryProvider.overrideWithValue(repositorio)],
        child: MaterialApp(theme: AppTheme.claro, home: const PacientesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los pacientes con su número y aviso de alergia', (
    tester,
  ) async {
    when(
      () => repositorio.listar(
        texto: any(named: 'texto'),
        archivados: any(named: 'archivados'),
        pagina: any(named: 'pagina'),
      ),
    ).thenAnswer(
      (_) async => paginaDe([
        pacientePrueba(nombre: 'Ana Ríos', alergias: 'Penicilina'),
        pacientePrueba(
          id: 'p-2',
          nombre: 'Juan Pérez',
          whatsapp: '+51912345678',
        ),
      ]),
    );

    await montar(tester);

    expect(find.text('Ana Ríos'), findsOneWidget);
    expect(find.text('+51 912 345 678'), findsOneWidget);
    expect(find.text('2 pacientes'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('la búsqueda consulta a la API con el texto escrito', (
    tester,
  ) async {
    when(
      () => repositorio.listar(
        texto: any(named: 'texto'),
        archivados: any(named: 'archivados'),
        pagina: any(named: 'pagina'),
      ),
    ).thenAnswer((_) async => paginaDe([]));

    await montar(tester);
    await tester.enterText(find.byType(TextField), 'perez');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    verify(
      () => repositorio.listar(texto: 'perez', archivados: false, pagina: 0),
    ).called(1);
    expect(
      find.text('No hay pacientes que coincidan con "perez".'),
      findsOneWidget,
    );
  });

  testWidgets('sin pacientes invita a registrar el primero', (tester) async {
    when(
      () => repositorio.listar(
        texto: any(named: 'texto'),
        archivados: any(named: 'archivados'),
        pagina: any(named: 'pagina'),
      ),
    ).thenAnswer((_) async => paginaDe([]));

    await montar(tester);

    expect(find.textContaining('Aún no hay pacientes'), findsOneWidget);
  });
}
