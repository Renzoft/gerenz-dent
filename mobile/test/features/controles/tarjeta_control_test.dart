import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/controles/presentation/tarjeta_control.dart';
import 'package:gerenz_dent/features/cuenta/data/cuenta_repository.dart';
import 'package:gerenz_dent/features/cuenta/domain/cuenta.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late ControlesRepositoryFalso controles;
  late TratamientosRepositoryFalso tratamientos;
  late CuentaRepositoryFalso cuenta;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(EstadoControl.pendiente);
  });

  setUp(() {
    controles = ControlesRepositoryFalso();
    tratamientos = TratamientosRepositoryFalso();
    cuenta = CuentaRepositoryFalso();
    // Por defecto el tratamiento ya está pagado: no se pregunta por el pago.
    when(() => cuenta.cuenta(any())).thenAnswer(
      (_) async => CuentaPaciente(
        deuda: 0,
        planes: [planCuentaPrueba(cargos: 500, pagos: 500)],
      ),
    );
    when(
      () => tratamientos.listar(),
    ).thenAnswer((_) async => [bracketsPrueba, puentePrueba]);
    when(() => controles.historial(any())).thenAnswer((_) async => []);
    when(() => controles.agenda()).thenAnswer((_) async => []);
    when(() => controles.vencidos()).thenAnswer((_) async => []);
  });

  Future<void> montar(WidgetTester tester, Control control) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controlesRepositoryProvider.overrideWithValue(controles),
          tratamientosRepositoryProvider.overrideWithValue(tratamientos),
          cuentaRepositoryProvider.overrideWithValue(cuenta),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TarjetaControl(
                control: control,
                pacienteNombre: 'Juan Pérez',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra tratamiento, fecha y si está vencido', (tester) async {
    await montar(
      tester,
      controlPrueba(
        fecha: Fechas.hoy().subtract(const Duration(days: 4)),
        vencido: true,
        diasAtraso: 4,
      ),
    );

    expect(find.text('Brackets (ortodoncia)'), findsOneWidget);
    expect(find.text('Vencido hace 4 días'), findsOneWidget);
    expect(find.text('Vencido'), findsOneWidget);
  });

  testWidgets('"Asistió" propone el siguiente control con la fecha sugerida', (
    tester,
  ) async {
    final sugerida = Fechas.hoy().add(const Duration(days: 30));
    when(
      () => controles.cambiarEstado('c-1', EstadoControl.asistio),
    ).thenAnswer(
      (_) async => CambioDeEstado(
        control: controlPrueba(estado: EstadoControl.asistio),
        siguienteFechaSugerida: sugerida,
      ),
    );
    when(
      () => controles.sugerencia(any(), any()),
    ).thenAnswer((_) async => sugerida);
    await montar(tester, controlPrueba());

    await tester.tap(find.text('Asistió'));
    await tester.pumpAndSettle();

    expect(find.text('¿Agendar el siguiente control?'), findsOneWidget);
    expect(find.textContaining(Fechas.larga(sugerida)), findsOneWidget);

    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();

    // Se abre la hoja con el mismo tratamiento y la fecha sugerida.
    expect(find.text('Próximo control'), findsOneWidget);
    expect(find.textContaining('Sugerida por el tratamiento'), findsOneWidget);
  });

  testWidgets('"No vino" está en "Otras opciones" y cambia el estado', (
    tester,
  ) async {
    when(
      () => controles.cambiarEstado('c-1', EstadoControl.noAsistio),
    ).thenAnswer(
      (_) async => CambioDeEstado(
        control: controlPrueba(estado: EstadoControl.noAsistio),
      ),
    );
    await montar(tester, controlPrueba());

    // La tarjeta muestra una sola acción principal; el resto va en la hoja.
    expect(find.text('No vino'), findsNothing);
    await tester.tap(find.text('Otras opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar fecha'), findsOneWidget);
    expect(find.text('El paciente confirmó'), findsOneWidget);
    await tester.tap(find.text('No vino'));
    await tester.pumpAndSettle();

    verify(
      () => controles.cambiarEstado('c-1', EstadoControl.noAsistio),
    ).called(1);
    expect(find.text('Control marcado: No vino'), findsOneWidget);
  });

  testWidgets('cancelar pide confirmación', (tester) async {
    await montar(tester, controlPrueba());

    await tester.tap(find.text('Otras opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar control'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar control'), findsWidgets);
    await tester.tap(find.text('No, volver'));
    await tester.pumpAndSettle();
    verifyNever(() => controles.cambiarEstado(any(), any()));
  });

  testWidgets('"Asistió" con deuda ofrece registrar el pago', (tester) async {
    registerFallbackValue(MedioPago.efectivo);
    when(() => cuenta.cuenta(any())).thenAnswer(
      (_) async => CuentaPaciente(
        deuda: 600,
        planes: [planCuentaPrueba(cargos: 600, pagos: 0)],
      ),
    );
    when(
      () => cuenta.registrarPago(
        any(),
        monto: any(named: 'monto'),
        medio: any(named: 'medio'),
        nota: any(named: 'nota'),
      ),
    ).thenAnswer((_) async => planCuentaPrueba(cargos: 600, pagos: 100));
    when(
      () => controles.cambiarEstado('c-1', EstadoControl.asistio),
    ).thenAnswer(
      (_) async =>
          CambioDeEstado(control: controlPrueba(estado: EstadoControl.asistio)),
    );
    await montar(tester, controlPrueba(planId: 'pl-1'));

    await tester.tap(find.text('Asistió'));
    await tester.pumpAndSettle();

    expect(find.text('¿Pagó algo hoy?'), findsOneWidget);
    expect(find.text('Brackets (ortodoncia): debe S/ 600.00.'), findsOneWidget);
    await tester.tap(find.text('Registrar pago'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.tap(find.text('Plin'));
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar pago'));
    await tester.pumpAndSettle();

    verify(
      () => cuenta.registrarPago(
        'pl-1',
        monto: 100,
        medio: MedioPago.plin,
        nota: any(named: 'nota'),
      ),
    ).called(1);
    // Luego sigue el flujo normal (sin fecha sugerida, termina aquí).
    expect(find.text('Asistencia registrada'), findsOneWidget);
  });
}
