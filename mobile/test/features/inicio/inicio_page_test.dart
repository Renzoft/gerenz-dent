import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/inicio/data/salud_repository.dart';
import 'package:gerenz_dent/features/inicio/presentation/inicio_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

class _SaludRepositoryFalso extends Mock implements SaludRepository {}

void main() {
  late _SaludRepositoryFalso repositorio;
  late ControlesRepositoryFalso controles;

  setUpAll(() => initializeDateFormatting('es_PE'));

  setUp(() {
    repositorio = _SaludRepositoryFalso();
    controles = ControlesRepositoryFalso();
    when(() => controles.agenda()).thenAnswer((_) async => <Control>[]);
    when(() => controles.vencidos()).thenAnswer((_) async => <Control>[]);
  });

  Future<void> montar(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          saludRepositoryProvider.overrideWithValue(repositorio),
          controlesRepositoryProvider.overrideWithValue(controles),
          almacenSesionProvider.overrideWithValue(
            AlmacenSesionMemoria(sesionPrueba()),
          ),
        ],
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

  testWidgets('lista los vencidos y los próximos controles con su paciente', (
    tester,
  ) async {
    when(() => repositorio.servidorDisponible()).thenAnswer((_) async => true);
    const ana = PacienteDelControl(
      id: 'p-ana',
      nombre: 'Ana Ríos',
      whatsapp: '+51912345678',
    );
    const juan = PacienteDelControl(
      id: 'p-juan',
      nombre: 'Juan Pérez',
      whatsapp: '+51987654321',
    );
    when(() => controles.vencidos()).thenAnswer(
      (_) async => [
        controlPrueba(
          id: 'c-v',
          pacienteId: 'p-ana',
          paciente: ana,
          vencido: true,
          diasAtraso: 3,
          fecha: Fechas.hoy().subtract(const Duration(days: 3)),
        ),
      ],
    );
    when(() => controles.agenda()).thenAnswer(
      (_) async => [
        controlPrueba(
          id: 'c-m',
          pacienteId: 'p-juan',
          paciente: juan,
          fecha: Fechas.hoy().add(const Duration(days: 1)),
        ),
      ],
    );

    await montar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Vencidos (1)'), findsOneWidget);
    expect(find.text('Ana Ríos'), findsOneWidget);
    expect(find.text('Brackets (ortodoncia) · hace 3 días'), findsOneWidget);
    expect(find.text('Próximos 7 días (1)'), findsOneWidget);
    expect(find.text('Brackets (ortodoncia) · Mañana'), findsOneWidget);
  });
}
