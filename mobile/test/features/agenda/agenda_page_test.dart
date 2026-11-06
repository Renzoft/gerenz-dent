import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/agenda/presentation/agenda_page.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late ControlesRepositoryFalso controles;
  final hoy = DateTime(2026, 11, 5);

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(DateTime(2026));
  });

  PacienteDelControl paciente(String nombre) => PacienteDelControl(
    id: 'p-$nombre',
    nombre: nombre,
    whatsapp: '+51987654321',
  );

  setUp(() {
    controles = ControlesRepositoryFalso();
    when(
      () => controles.agenda(
        desde: any(named: 'desde'),
        hasta: any(named: 'hasta'),
        cerrados: any(named: 'cerrados'),
      ),
    ).thenAnswer((inv) async {
      final desde = inv.namedArguments[#desde] as DateTime;
      if (desde.month != 11) return <Control>[];
      return [
        controlPrueba(
          id: 'c-1',
          pacienteId: 'p-rosa',
          paciente: paciente('Rosa Quispe'),
          fecha: DateTime(2026, 11, 5),
          estado: EstadoControl.asistio,
        ),
        controlPrueba(
          id: 'c-2',
          pacienteId: 'p-juan',
          paciente: paciente('Juan Pérez'),
          fecha: DateTime(2026, 11, 5),
          hora: const TimeOfDay(hour: 19, minute: 30),
        ),
        controlPrueba(
          id: 'c-3',
          pacienteId: 'p-ana',
          paciente: paciente('Ana Ríos'),
          fecha: DateTime(2026, 11, 12),
        ),
      ];
    });
  });

  Widget app() => ProviderScope(
    overrides: [controlesRepositoryProvider.overrideWithValue(controles)],
    child: MaterialApp(
      theme: AppTheme.claro,
      home: AgendaPage(hoy: hoy),
    ),
  );

  Future<void> montar(WidgetTester tester, {Size? tamano}) async {
    tester.view.physicalSize = tamano ?? const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el mes y los controles de hoy, también los atendidos', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.textContaining('Hoy · Jueves 5 de noviembre'), findsOneWidget);
    expect(find.text('Rosa Quispe'), findsOneWidget);
    expect(find.text('Asistió'), findsOneWidget);
    expect(find.text('Juan Pérez'), findsOneWidget);
    verify(
      () => controles.agenda(
        desde: DateTime(2026, 11),
        hasta: DateTime(2026, 11, 30),
        cerrados: true,
      ),
    ).called(1);
  });

  testWidgets('al tocar otro día muestra sus controles o que no hay', (
    tester,
  ) async {
    await montar(tester);

    await tester.tap(
      find.bySemanticsLabel('jueves 12 de noviembre, 1 control'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Ríos'), findsOneWidget);
    expect(find.text('Rosa Quispe'), findsNothing);

    await tester.tap(
      find.bySemanticsLabel('viernes 20 de noviembre, sin controles'),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay controles este día.'), findsOneWidget);
  });

  testWidgets('las flechas cambian de mes y "Hoy" vuelve al día actual', (
    tester,
  ) async {
    await montar(tester);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Diciembre 2026'), findsOneWidget);
    verify(
      () => controles.agenda(
        desde: DateTime(2026, 12),
        hasta: DateTime(2026, 12, 31),
        cerrados: true,
      ),
    ).called(1);

    await tester.tap(find.text('Hoy'));
    await tester.pumpAndSettle();
    expect(find.text('Noviembre 2026'), findsOneWidget);
    expect(find.text('Rosa Quispe'), findsOneWidget);
  });

  testWidgets('a 320 dp y con letra al 200 % no se desborda', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await montar(tester, tamano: const Size(320, 1600));

    expect(tester.takeException(), isNull);
    expect(find.text('Rosa Quispe'), findsOneWidget);
  });
}
