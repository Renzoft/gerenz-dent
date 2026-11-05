import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/network/api_error.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/controles/presentation/agendar_control_sheet.dart';
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
  Control? resultado;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(
      NuevoControl(pacienteId: '', tratamientoId: '', fecha: DateTime(2026)),
    );
  });

  setUp(() {
    controles = ControlesRepositoryFalso();
    tratamientos = TratamientosRepositoryFalso();
    cuenta = CuentaRepositoryFalso();
    when(() => cuenta.cuenta(any())).thenAnswer((_) async => cuentaVacia);
    resultado = null;
    when(
      () => tratamientos.listar(),
    ).thenAnswer((_) async => [bracketsPrueba, puentePrueba]);
    when(
      () => controles.sugerencia(any(), 't-brackets'),
    ).thenAnswer((_) async => Fechas.hoy().add(const Duration(days: 30)));
    when(() => controles.historial(any())).thenAnswer((_) async => <Control>[]);
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          controlesRepositoryProvider.overrideWithValue(controles),
          tratamientosRepositoryProvider.overrideWithValue(tratamientos),
          cuentaRepositoryProvider.overrideWithValue(cuenta),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => resultado = await mostrarAgendarControl(
                  context,
                  pacienteId: 'p-1',
                  pacienteNombre: 'Juan Pérez',
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> elegirTratamiento(WidgetTester tester, String nombre) async {
    await tester.tap(find.byKey(const Key('tratamiento')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> tocarAgendar(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Agendar control'));
    await tester.tap(find.text('Agendar control'));
    await tester.pumpAndSettle();
  }

  testWidgets('exige tratamiento antes de agendar', (tester) async {
    await abrir(tester);

    await tocarAgendar(tester);

    expect(find.text('Elige el tratamiento'), findsOneWidget);
    verifyNever(() => controles.agendar(any()));
  });

  testWidgets('al elegir brackets preselecciona la fecha sugerida (+30 días)', (
    tester,
  ) async {
    final sugerida = Fechas.hoy().add(const Duration(days: 30));
    when(
      () => controles.agendar(any()),
    ).thenAnswer((_) async => controlPrueba(fecha: sugerida));
    await abrir(tester);

    await elegirTratamiento(tester, 'Brackets (ortodoncia)');

    expect(find.textContaining('Sugerida por el tratamiento'), findsOneWidget);
    await tocarAgendar(tester);

    final enviado =
        verify(() => controles.agendar(captureAny())).captured.single
            as NuevoControl;
    expect(enviado.tratamientoId, 't-brackets');
    expect(enviado.fecha, sugerida);
    expect(enviado.piezas, isNull);
    expect(resultado, isNotNull);
  });

  testWidgets('en tratamientos por pieza pide las piezas', (tester) async {
    when(
      () => controles.agendar(any()),
    ).thenAnswer((_) async => controlPrueba(tratamiento: puentePrueba));
    await abrir(tester);

    await elegirTratamiento(tester, 'Puente de zirconio');
    await tester.tap(find.byTooltip('Más piezas'));
    await tester.tap(find.text('En 1 semana'));
    await tester.pump();
    await tocarAgendar(tester);

    final enviado =
        verify(() => controles.agendar(captureAny())).captured.single
            as NuevoControl;
    expect(enviado.piezas, 2);
    expect(enviado.fecha, Fechas.hoy().add(const Duration(days: 7)));
  });

  testWidgets('muestra el aviso si ya hay un control pendiente', (
    tester,
  ) async {
    when(() => controles.agendar(any())).thenThrow(
      const ApiError(
        mensaje: 'Juan Pérez ya tiene un control de Brackets pendiente.',
        estado: 409,
      ),
    );
    await abrir(tester);

    await elegirTratamiento(tester, 'Brackets (ortodoncia)');
    await tocarAgendar(tester);

    expect(
      find.text('Juan Pérez ya tiene un control de Brackets pendiente.'),
      findsOneWidget,
    );
    expect(resultado, isNull);
  });

  testWidgets(
    'primer control: propone el costo del catálogo y el pago del día',
    (tester) async {
      when(
        () => controles.agendar(any()),
      ).thenAnswer((_) async => controlPrueba());
      await abrir(tester);

      await elegirTratamiento(tester, 'Brackets (ortodoncia)');
      expect(find.text('Pago inicial'), findsOneWidget);
      expect(find.text('Luego S/ 100.00 cada vez que asista'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('costo')))
            .controller!
            .text,
        '500.00',
      );

      await tester.enterText(find.byKey(const Key('costo')), '450');
      await tester.enterText(find.byKey(const Key('pago-hoy')), '200');
      await tester.pump();
      await tester.ensureVisible(find.text('Yape'));
      await tester.tap(find.text('Yape'));
      await tocarAgendar(tester);

      final enviado =
          verify(() => controles.agendar(captureAny())).captured.single
              as NuevoControl;
      expect(enviado.costo, 450);
      expect(enviado.pagoInicial, 200);
      expect(enviado.medioPago, 'YAPE');
    },
  );

  testWidgets('por pieza: el costo se multiplica por las piezas', (
    tester,
  ) async {
    await abrir(tester);

    await elegirTratamiento(tester, 'Puente de zirconio');
    await tester.tap(find.byTooltip('Más piezas'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byKey(const Key('costo'))).controller!.text,
      '1400.00',
    );
  });

  testWidgets('no deja registrar un pago mayor al costo', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('En 1 semana')); // sin fecha sugerida: se elige
    await elegirTratamiento(tester, 'Puente de zirconio');
    await tester.enterText(find.byKey(const Key('pago-hoy')), '900');
    await tester.pump();
    await tocarAgendar(tester);

    expect(
      find.text('Lo pagado no puede ser mayor que el costo'),
      findsOneWidget,
    );
    verifyNever(() => controles.agendar(any()));
  });

  testWidgets('si el tratamiento ya está en curso no vuelve a cobrar', (
    tester,
  ) async {
    when(() => cuenta.cuenta(any())).thenAnswer(
      (_) async => CuentaPaciente(deuda: 300, planes: [planCuentaPrueba()]),
    );
    await abrir(tester);

    await elegirTratamiento(tester, 'Brackets (ortodoncia)');

    expect(find.byKey(const Key('costo')), findsNothing);
    expect(find.text('Cobro'), findsNothing);
  });
}
