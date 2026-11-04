import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/controles/presentation/tarjeta_control.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late ControlesRepositoryFalso controles;
  late TratamientosRepositoryFalso tratamientos;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(EstadoControl.pendiente);
  });

  setUp(() {
    controles = ControlesRepositoryFalso();
    tratamientos = TratamientosRepositoryFalso();
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

  testWidgets('"No vino" cambia el estado sin preguntar', (tester) async {
    when(
      () => controles.cambiarEstado('c-1', EstadoControl.noAsistio),
    ).thenAnswer(
      (_) async => CambioDeEstado(
        control: controlPrueba(estado: EstadoControl.noAsistio),
      ),
    );
    await montar(tester, controlPrueba());

    await tester.tap(find.text('No vino'));
    await tester.pumpAndSettle();

    verify(
      () => controles.cambiarEstado('c-1', EstadoControl.noAsistio),
    ).called(1);
    expect(find.text('Control marcado: No vino'), findsOneWidget);
  });

  testWidgets('cancelar pide confirmación', (tester) async {
    await montar(tester, controlPrueba());

    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar control'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar control'), findsWidgets);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => controles.cambiarEstado(any(), any()));
  });
}
