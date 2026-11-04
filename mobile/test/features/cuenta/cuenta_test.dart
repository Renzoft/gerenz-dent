import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/moneda.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/cuenta/data/cuenta_repository.dart';
import 'package:gerenz_dent/features/cuenta/domain/cuenta.dart';
import 'package:gerenz_dent/features/cuenta/presentation/deudas_page.dart';
import 'package:gerenz_dent/features/cuenta/presentation/seccion_cuenta.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(MedioPago.efectivo);
  });

  group('Moneda', () {
    test('formatea en soles con separadores peruanos', () {
      expect(Moneda.formatear(1300), 'S/ 1,300.00');
      expect(Moneda.formatear(70.5), 'S/ 70.50');
      expect(Moneda.formatear(0), 'S/ 0.00');
    });

    test('lee lo que escribe el doctor', () {
      expect(Moneda.leer('150'), 150);
      expect(Moneda.leer('150.5'), 150.5);
      expect(Moneda.leer('1,300.50'), 1300.5);
      expect(Moneda.leer('150,50'), 150.5);
      expect(Moneda.leer('S/ 80'), 80);
      expect(Moneda.leer(''), isNull);
      expect(Moneda.leer('abc'), isNull);
    });
  });

  test('lee la cuenta de la API', () {
    final c = CuentaPaciente.fromJson({
      'deuda': 300.00,
      'planes': [
        {
          'planId': 'pl-1',
          'pacienteId': 'p-1',
          'tratamiento': {
            'id': 't-1',
            'nombre': 'Brackets (ortodoncia)',
            'tipoPrecio': 'INICIAL_MAS_MENSUAL',
          },
          'piezas': null,
          'estado': 'ACTIVO',
          'fechaInicio': '2026-11-01',
          'totalCargos': 600.00,
          'totalPagos': 300.00,
          'saldo': 300.00,
          'cargos': [
            {
              'id': 'c-1',
              'concepto': 'INICIAL',
              'monto': 500.00,
              'fecha': '2026-11-01',
              'estado': 'VALIDO',
            },
            {
              'id': 'c-2',
              'concepto': 'MENSUAL',
              'monto': 100.00,
              'fecha': '2026-12-01',
              'estado': 'VALIDO',
            },
          ],
          'pagos': [
            {
              'id': 'g-1',
              'monto': 300.00,
              'fecha': '2026-11-01',
              'medio': 'YAPE',
              'estado': 'VALIDO',
            },
          ],
        },
      ],
    });

    expect(c.deuda, 300);
    expect(c.planes.single.cargos.last.concepto, ConceptoCargo.mensual);
    expect(c.planes.single.pagos.single.medio, MedioPago.yape);
    expect(c.planActivoDe('t-1'), isNotNull);
    expect(c.planActivoDe('otro'), isNull);
  });

  group('Pestaña Deudas', () {
    late CuentaRepositoryFalso repo;

    setUp(() => repo = CuentaRepositoryFalso());

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cuentaRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(theme: AppTheme.claro, home: const DeudasPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el total y los pacientes', (tester) async {
      when(() => repo.deudas()).thenAnswer(
        (_) async => const ResumenDeudas(
          total: 1470,
          pacientes: [
            DeudaPaciente(
              pacienteId: 'p-1',
              nombre: 'Ana Ríos',
              whatsapp: '+51912345678',
              deuda: 1400,
              archivado: true,
            ),
            DeudaPaciente(
              pacienteId: 'p-2',
              nombre: 'Juan Pérez',
              whatsapp: '+51987654321',
              deuda: 70,
            ),
          ],
        ),
      );
      await montar(tester);

      expect(find.text('S/ 1,470.00'), findsOneWidget);
      expect(find.text('2 pacientes con deuda'), findsOneWidget);
      expect(find.text('Ana Ríos'), findsOneWidget);
      expect(find.text('Archivado'), findsOneWidget);
      expect(find.text('S/ 70.00'), findsOneWidget);
    });

    testWidgets('sin deudas lo dice', (tester) async {
      when(
        () => repo.deudas(),
      ).thenAnswer((_) async => const ResumenDeudas(total: 0, pacientes: []));
      await montar(tester);

      expect(find.text('Nadie tiene deuda pendiente'), findsOneWidget);
    });
  });

  group('Deuda en la ficha', () {
    late CuentaRepositoryFalso repo;

    setUp(() => repo = CuentaRepositoryFalso());

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cuentaRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SeccionCuenta(pacienteId: 'p-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la deuda por tratamiento', (tester) async {
      when(() => repo.cuenta('p-1')).thenAnswer(
        (_) async => CuentaPaciente(
          deuda: 300,
          planes: [planCuentaPrueba(cargos: 600, pagos: 300)],
        ),
      );
      await montar(tester);

      expect(find.text('S/ 300.00'), findsOneWidget);
      expect(find.text('Total S/ 600.00 · Pagado S/ 300.00'), findsOneWidget);
      expect(find.text('Debe S/ 300.00'), findsOneWidget);
      expect(find.text('Registrar pago'), findsOneWidget);
    });

    testWidgets('registrar pago valida que no supere la deuda', (tester) async {
      when(() => repo.cuenta('p-1')).thenAnswer(
        (_) async => CuentaPaciente(
          deuda: 300,
          planes: [planCuentaPrueba(cargos: 300, pagos: 0)],
        ),
      );
      await montar(tester);

      await tester.tap(find.text('Registrar pago'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '500');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Registrar pago').last,
      );
      await tester.pumpAndSettle();

      expect(find.text('El pago supera la deuda de S/ 300.00'), findsOneWidget);
      verifyNever(
        () => repo.registrarPago(
          any(),
          monto: any(named: 'monto'),
          medio: any(named: 'medio'),
          nota: any(named: 'nota'),
        ),
      );
    });

    testWidgets('"Todo" completa el saldo y registra el pago', (tester) async {
      when(() => repo.cuenta('p-1')).thenAnswer(
        (_) async => CuentaPaciente(
          deuda: 300,
          planes: [planCuentaPrueba(cargos: 300, pagos: 0)],
        ),
      );
      when(
        () => repo.registrarPago(
          any(),
          monto: any(named: 'monto'),
          medio: any(named: 'medio'),
          nota: any(named: 'nota'),
        ),
      ).thenAnswer((_) async => planCuentaPrueba(cargos: 300, pagos: 300));
      await montar(tester);

      await tester.tap(find.text('Registrar pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todo'));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Registrar pago').last,
      );
      await tester.pumpAndSettle();

      verify(
        () => repo.registrarPago(
          'pl-1',
          monto: 300,
          medio: MedioPago.efectivo,
          nota: any(named: 'nota'),
        ),
      ).called(1);
    });

    testWidgets('sin tratamientos no muestra la sección', (tester) async {
      when(() => repo.cuenta('p-1')).thenAnswer((_) async => cuentaVacia);
      await montar(tester);

      expect(find.text('Deuda'), findsNothing);
    });
  });
}
