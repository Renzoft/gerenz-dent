import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/cuenta/data/cuenta_repository.dart';
import 'package:gerenz_dent/features/cuenta/domain/cuenta.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/presentation/paciente_detalle_page.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

/// Ficha del paciente (rediseño v2, pantalla piloto). Datos ficticios.
void main() {
  late PacientesRepositoryFalso pacientes;
  late ControlesRepositoryFalso controles;
  late CuentaRepositoryFalso cuenta;
  late TratamientosRepositoryFalso tratamientos;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    pacientes = PacientesRepositoryFalso();
    controles = ControlesRepositoryFalso();
    cuenta = CuentaRepositoryFalso();
    tratamientos = TratamientosRepositoryFalso();
    when(() => pacientes.obtener('p-1')).thenAnswer(
      (_) async => pacientePrueba(nombre: 'Ana Ríos', alergias: 'Penicilina'),
    );
    when(() => controles.historial('p-1')).thenAnswer(
      (_) async => [
        controlPrueba(
          id: 'c-1',
          fecha: Fechas.hoy().add(const Duration(days: 1)),
          estado: EstadoControl.recordado,
        ),
        controlPrueba(
          id: 'c-2',
          fecha: Fechas.hoy().add(const Duration(days: 30)),
          tratamiento: puentePrueba,
        ),
        controlPrueba(id: 'c-0', estado: EstadoControl.asistio),
      ],
    );
    when(() => cuenta.cuenta('p-1')).thenAnswer(
      (_) async => CuentaPaciente(
        deuda: 300,
        planes: [planCuentaPrueba(cargos: 600, pagos: 300)],
      ),
    );
    when(() => tratamientos.listar()).thenAnswer((_) async => []);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pacientesRepositoryProvider.overrideWithValue(pacientes),
          controlesRepositoryProvider.overrideWithValue(controles),
          cuentaRepositoryProvider.overrideWithValue(cuenta),
          tratamientosRepositoryProvider.overrideWithValue(tratamientos),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          home: const PacienteDetallePage(pacienteId: 'p-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cabecera con alergia y resumen de próximo control y deuda', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Ana Ríos'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    expect(find.text('Penicilina'), findsNothing); // va dentro del aviso
    expect(find.textContaining('Penicilina', findRichText: true), findsOne);
    expect(find.text('Próximo: Mañana'), findsOneWidget);
    expect(find.text('Debe S/ 300.00'), findsOneWidget);
  });

  testWidgets('solo el control más cercano lleva "Asistió" principal', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Próximos controles'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Asistió'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Asistió'), findsOneWidget);
    // Estados con ícono y texto, también en el historial.
    expect(find.text('Recordado'), findsOneWidget);
    expect(find.text('Por recordar'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Asistió'), findsNWidgets(3));
  });

  testWidgets('las pestañas agrupan pagos y datos', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Pagos'));
    await tester.pumpAndSettle();
    expect(find.text('Deuda total'), findsOneWidget);
    expect(find.text('Total S/ 600.00 · Pagado S/ 300.00'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Registrar pago'), findsOne);

    await tester.tap(find.text('Datos'));
    await tester.pumpAndSettle();
    expect(find.text('Datos del paciente'), findsOneWidget);
    expect(find.text('Archivar paciente'), findsOneWidget);
  });

  testWidgets('el resumen de deuda lleva a la pestaña Pagos', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Debe S/ 300.00'));
    await tester.pumpAndSettle();
    expect(find.text('Deuda total'), findsOneWidget);
  });

  testWidgets(
    'un "No vino" sin fecha muestra "Poner nueva fecha" y la guarda',
    (tester) async {
      final hoy = Fechas.hoy();
      when(() => controles.historial('p-1')).thenAnswer(
        (_) async => [
          controlPrueba(
            id: 'c-nv',
            planId: 'pl-1',
            fecha: hoy.subtract(const Duration(days: 2)),
            estado: EstadoControl.noAsistio,
          ),
        ],
      );
      when(
        () => controles.reprogramar(
          any(),
          any(),
          any(),
          confirmado: any(named: 'confirmado'),
        ),
      ).thenAnswer(
        (_) async => controlPrueba(
          id: 'c-nuevo',
          planId: 'pl-1',
          fecha: hoy.add(const Duration(days: 7)),
        ),
      );
      await montar(tester);

      expect(find.text('Falta nueva fecha'), findsWidgets);
      expect(find.text('No tiene un control agendado.'), findsNothing);
      final boton = find.widgetWithText(FilledButton, 'Poner nueva fecha');
      expect(boton, findsOneWidget);

      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('¿Cuándo vuelve?'), findsOneWidget);
      // Aquí no se ofrece "Todavía no sabe": ya está en seguimiento.
      expect(find.text('Todavía no sabe'), findsNothing);
      await tester.tap(find.text('En 1 semana'));
      await tester.pumpAndSettle();
      // La fecha la dio el paciente: se pregunta si confirmó.
      expect(find.text('¿El paciente confirmó esta fecha?'), findsOneWidget);
      await tester.tap(find.text('Sí, confirmó'));
      await tester.pumpAndSettle();

      verify(
        () => controles.reprogramar(
          'c-nv',
          hoy.add(const Duration(days: 7)),
          null,
          confirmado: true,
        ),
      ).called(1);
      expect(
        find.textContaining('Ya confirmó: no se le enviará recordatorio.'),
        findsOneWidget,
      );
    },
  );
}
