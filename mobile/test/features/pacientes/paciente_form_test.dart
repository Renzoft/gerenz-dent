import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/network/api_error.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/domain/paciente.dart';
import 'package:gerenz_dent/features/pacientes/presentation/paciente_form_page.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

void main() {
  late PacientesRepositoryFalso repositorio;

  setUpAll(
    () => registerFallbackValue(const DatosPaciente(nombre: '', whatsapp: '')),
  );

  setUp(() {
    repositorio = PacientesRepositoryFalso();
    when(
      () => repositorio.listar(
        texto: any(named: 'texto'),
        archivados: any(named: 'archivados'),
        pagina: any(named: 'pagina'),
      ),
    ).thenAnswer((_) async => paginaDe([]));
  });

  Future<void> montar(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PacienteFormPage()),
        GoRoute(
          path: '/pacientes/:id',
          builder: (_, s) => Text('Ficha ${s.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pacientesRepositoryProvider.overrideWithValue(repositorio)],
        child: MaterialApp.router(theme: AppTheme.claro, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

  testWidgets('exige nombre y WhatsApp', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Ingresa el nombre'), findsOneWidget);
    expect(find.text('Ingresa el número de WhatsApp'), findsOneWidget);
    verifyNever(() => repositorio.crear(any()));
  });

  testWidgets('avisa si el número no es válido', (tester) async {
    await montar(tester);

    await tester.enterText(campo('Nombre *'), 'Juan');
    await tester.enterText(campo('WhatsApp *'), '12345');
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Celular de 9 dígitos que empiece con 9'), findsOneWidget);
  });

  testWidgets('crea el paciente y abre su ficha', (tester) async {
    when(
      () => repositorio.crear(any()),
    ).thenAnswer((_) async => pacientePrueba(id: 'nuevo-1'));
    await montar(tester);

    await tester.enterText(campo('Nombre *'), '  Juan Pérez ');
    await tester.enterText(campo('WhatsApp *'), '987 654 321');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final enviado =
        verify(() => repositorio.crear(captureAny())).captured.single
            as DatosPaciente;
    expect(enviado.nombre, 'Juan Pérez');
    expect(enviado.whatsapp, '987 654 321');
    expect(enviado.consienteWhatsapp, isTrue);
    expect(enviado.edad, isNull);
    expect(find.text('Ficha nuevo-1'), findsOneWidget);
  });

  testWidgets('si el número ya existe ofrece abrir ese paciente', (
    tester,
  ) async {
    when(() => repositorio.crear(any())).thenThrow(
      const ApiError(
        mensaje: 'Ya existe un paciente con ese número: Ana Ríos.',
        estado: 409,
        datos: {'pacienteExistenteId': 'p-ana'},
      ),
    );
    await montar(tester);

    await tester.enterText(campo('Nombre *'), 'Juan');
    await tester.enterText(campo('WhatsApp *'), '987654321');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Número ya registrado'), findsOneWidget);
    await tester.tap(find.text('Ver paciente'));
    await tester.pumpAndSettle();
    expect(find.text('Ficha p-ana'), findsOneWidget);
  });

  testWidgets('muestra en el campo el error que devuelve la API', (
    tester,
  ) async {
    when(() => repositorio.crear(any())).thenThrow(
      const ApiError(
        mensaje: 'Datos inválidos',
        estado: 400,
        errores: {'nombre': 'El nombre debe tener entre 2 y 80 caracteres'},
      ),
    );
    await montar(tester);

    await tester.enterText(campo('Nombre *'), 'Juan');
    await tester.enterText(campo('WhatsApp *'), '987654321');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El nombre debe tener entre 2 y 80 caracteres'),
      findsOneWidget,
    );
  });
}
