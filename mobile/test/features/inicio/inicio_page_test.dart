import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/avisos/avisos_diarios.dart';
import 'package:gerenz_dent/core/avisos/envio_whatsapp.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/controles/data/controles_repository.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/inicio/data/salud_repository.dart';
import 'package:gerenz_dent/features/inicio/presentation/inicio_page.dart';
import 'package:gerenz_dent/features/recordatorios/data/recordatorios_repository.dart';
import 'package:gerenz_dent/features/recordatorios/domain/mensaje_recordatorio.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

class _SaludRepositoryFalso extends Mock implements SaludRepository {}

void main() {
  late _SaludRepositoryFalso salud;
  late ControlesRepositoryFalso controles;
  late RecordatoriosRepositoryFalso recordatorios;
  late ServicioAvisosFalso avisos;
  late EnvioWhatsappFalso whatsapp;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(TipoRecordatorio.previo);
  });

  setUp(() {
    salud = _SaludRepositoryFalso();
    controles = ControlesRepositoryFalso();
    recordatorios = RecordatoriosRepositoryFalso();
    avisos = ServicioAvisosFalso();
    whatsapp = EnvioWhatsappFalso();
    when(() => salud.servidorDisponible()).thenAnswer((_) async => true);
    when(() => controles.agenda()).thenAnswer((_) async => <Control>[]);
    when(() => recordatorios.pendientes()).thenAnswer((_) async => []);
    when(() => recordatorios.seguimientos()).thenAnswer((_) async => []);
    when(
      () => recordatorios.registrarEnvio(any(), any()),
    ).thenAnswer((_) async {});
  });

  Widget app() => ProviderScope(
    overrides: [
      saludRepositoryProvider.overrideWithValue(salud),
      controlesRepositoryProvider.overrideWithValue(controles),
      recordatoriosRepositoryProvider.overrideWithValue(recordatorios),
      servicioAvisosProvider.overrideWithValue(avisos),
      envioWhatsappProvider.overrideWithValue(whatsapp),
      almacenSesionProvider.overrideWithValue(
        AlmacenSesionMemoria(sesionPrueba()),
      ),
    ],
    child: MaterialApp(theme: AppTheme.claro, home: const InicioPage()),
  );

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('muestra "Conectando…" mientras espera al servidor', (
    tester,
  ) async {
    when(
      () => salud.servidorDisponible(),
    ).thenAnswer((_) => Future.delayed(const Duration(seconds: 1), () => true));

    await tester.pumpWidget(app());

    expect(find.text('Conectando con el consultorio…'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Conectando con el consultorio…'), findsNothing);
  });

  testWidgets('si falla, "Reintentar" vuelve a consultar', (tester) async {
    var llamadas = 0;
    when(() => salud.servidorDisponible()).thenAnswer((_) async {
      llamadas++;
      if (llamadas == 1) throw Exception('sin conexión');
      return true;
    });
    await montar(tester);

    expect(find.text('No se pudo conectar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar'), findsNothing);
    expect(llamadas, 2);
  });

  testWidgets('saluda al doctor y muestra las secciones vacías', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Bienvenido, Dr. Marco Munayco'), findsOneWidget);
    expect(find.text('Recordar para mañana (0)'), findsOneWidget);
    expect(find.text('No hay controles para mañana.'), findsOneWidget);
    expect(find.text('Vencidos (0)'), findsOneWidget);
    // Sin nada por enviar, el aviso de hoy no se programa con cantidad > 0.
    expect(avisos.programaciones.last.pendientesHoy, 0);
  });

  testWidgets('lista los recordatorios de mañana según su estado', (
    tester,
  ) async {
    when(() => recordatorios.pendientes()).thenAnswer(
      (_) async => [
        mensajePrueba(controlId: 'c-1', paciente: 'Juan Pérez'),
        mensajePrueba(controlId: 'c-2', paciente: 'Ana Ríos', enviado: true),
        mensajePrueba(
          controlId: 'c-3',
          paciente: 'Luis Soto',
          consiente: false,
        ),
        mensajePrueba(controlId: 'c-4', paciente: 'Eva Paz'),
      ],
    );
    await montar(tester);

    expect(find.text('Recordar para mañana (4)'), findsOneWidget);
    expect(find.text('Enviar'), findsNWidgets(2));
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('No autoriza\nWhatsApp'), findsOneWidget);
    expect(find.text('Enviar todos uno por uno (2)'), findsOneWidget);
    // El aviso de hoy se programa con los que faltan enviar.
    expect(avisos.programaciones.last.pendientesHoy, 2);
  });

  testWidgets('"Enviar" abre WhatsApp y registra el envío al confirmar', (
    tester,
  ) async {
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba()]);
    await montar(tester);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(whatsapp.abiertos, ['https://wa.me/51987654321?text=Hola']);
    expect(find.text('¿Se envió el mensaje a Juan Pérez?'), findsOneWidget);

    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    verify(
      () => recordatorios.registrarEnvio('c-1', TipoRecordatorio.previo),
    ).called(1);
    expect(find.text('Recordatorio registrado'), findsOneWidget);
  });

  testWidgets('si responde "No", no se registra', (tester) async {
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba()]);
    await montar(tester);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    verifyNever(() => recordatorios.registrarEnvio(any(), any()));
  });

  testWidgets('"Enviar todos" recorre los pendientes uno por uno', (
    tester,
  ) async {
    when(() => recordatorios.pendientes()).thenAnswer(
      (_) async => [
        mensajePrueba(controlId: 'c-1', paciente: 'Juan Pérez'),
        mensajePrueba(controlId: 'c-2', paciente: 'Ana Ríos'),
      ],
    );
    await montar(tester);

    await tester.tap(find.text('Enviar todos uno por uno (2)'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se envió el mensaje a Juan Pérez?'), findsOneWidget);
    expect(find.text('Detener'), findsOneWidget); // todavía queda Ana
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    expect(find.text('¿Se envió el mensaje a Ana Ríos?'), findsOneWidget);
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    expect(whatsapp.abiertos, hasLength(2));
    verify(() => recordatorios.registrarEnvio('c-1', any())).called(1);
    verify(() => recordatorios.registrarEnvio('c-2', any())).called(1);
    expect(find.text('2 recordatorios enviados'), findsOneWidget);
  });

  testWidgets('"Detener" corta el envío en lote', (tester) async {
    when(() => recordatorios.pendientes()).thenAnswer(
      (_) async => [
        mensajePrueba(controlId: 'c-1', paciente: 'Juan Pérez'),
        mensajePrueba(controlId: 'c-2', paciente: 'Ana Ríos'),
      ],
    );
    await montar(tester);

    await tester.tap(find.text('Enviar todos uno por uno (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Detener'));
    await tester.pumpAndSettle();

    expect(whatsapp.abiertos, hasLength(1));
    verifyNever(() => recordatorios.registrarEnvio(any(), any()));
  });

  testWidgets('los vencidos ofrecen enviar un seguimiento', (tester) async {
    when(() => recordatorios.seguimientos()).thenAnswer(
      (_) async => [
        mensajePrueba(
          controlId: 'c-v',
          paciente: 'Luis Soto',
          tipo: TipoRecordatorio.seguimiento,
          diasAtraso: 3,
        ),
      ],
    );
    await montar(tester);

    expect(find.text('Vencidos (1)'), findsOneWidget);
    expect(find.text('Brackets (ortodoncia) · hace 3 días'), findsOneWidget);

    await tester.tap(find.text('Seguimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    verify(
      () => recordatorios.registrarEnvio('c-v', TipoRecordatorio.seguimiento),
    ).called(1);
  });

  testWidgets('muestra los próximos 7 días con su paciente', (tester) async {
    when(() => controles.agenda()).thenAnswer(
      (_) async => [
        controlPrueba(
          id: 'c-m',
          pacienteId: 'p-juan',
          paciente: const PacienteDelControl(
            id: 'p-juan',
            nombre: 'Juan Pérez',
            whatsapp: '+51987654321',
          ),
          fecha: Fechas.hoy().add(const Duration(days: 2)),
        ),
      ],
    );
    await montar(tester);

    expect(find.text('Próximos 7 días (1)'), findsOneWidget);
    expect(find.text('Juan Pérez'), findsOneWidget);
  });

  testWidgets('si WhatsApp no abre, avisa y no pregunta', (tester) async {
    whatsapp = EnvioWhatsappFalso(exito: false);
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba()]);
    await montar(tester);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir WhatsApp.'), findsOneWidget);
    expect(find.textContaining('¿Se envió'), findsNothing);
  });
}
