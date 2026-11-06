import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/avisos/avisos_diarios.dart';
import 'package:gerenz_dent/core/avisos/envio_whatsapp.dart';
import 'package:gerenz_dent/core/formato/fechas.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/auth/data/perfil_repository.dart';
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

class _PerfilFalso extends Mock implements PerfilRepository {}

void main() {
  late _SaludRepositoryFalso salud;
  late ControlesRepositoryFalso controles;
  late RecordatoriosRepositoryFalso recordatorios;
  late ServicioAvisosFalso avisos;
  late EnvioWhatsappFalso whatsapp;
  late _PerfilFalso perfil;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(TipoRecordatorio.previo);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    salud = _SaludRepositoryFalso();
    controles = ControlesRepositoryFalso();
    recordatorios = RecordatoriosRepositoryFalso();
    avisos = ServicioAvisosFalso();
    whatsapp = EnvioWhatsappFalso();
    perfil = _PerfilFalso();
    when(() => salud.servidorDisponible()).thenAnswer((_) async => true);
    when(() => controles.agenda()).thenAnswer((_) async => <Control>[]);
    when(() => recordatorios.pendientes()).thenAnswer((_) async => []);
    when(() => recordatorios.seguimientos()).thenAnswer((_) async => []);
    when(
      () => recordatorios.registrarEnvio(any(), any()),
    ).thenAnswer((_) async {});
    when(() => perfil.yo()).thenAnswer((_) async => usuarioPrueba);
  });

  Widget app() => ProviderScope(
    overrides: [
      saludRepositoryProvider.overrideWithValue(salud),
      controlesRepositoryProvider.overrideWithValue(controles),
      recordatoriosRepositoryProvider.overrideWithValue(recordatorios),
      servicioAvisosProvider.overrideWithValue(avisos),
      envioWhatsappProvider.overrideWithValue(whatsapp),
      perfilRepositoryProvider.overrideWithValue(perfil),
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

  PacienteDelControl paciente(String nombre) => PacienteDelControl(
    id: 'p-$nombre',
    nombre: nombre,
    whatsapp: '+51987654321',
  );

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

  testWidgets('saluda con el nombre corto y explica cada tarjeta vacía', (
    tester,
  ) async {
    await montar(tester);

    expect(find.textContaining(', Dr. Marco'), findsOneWidget);
    expect(find.textContaining('Chacón'), findsNothing);
    expect(find.text('Recordatorios de mañana'), findsOneWidget);
    expect(find.text('Mañana no tienes pacientes citados.'), findsOneWidget);
    expect(find.text('Hoy no hay pacientes citados.'), findsOneWidget);
    expect(find.text('Todos vinieron a su control.'), findsOneWidget);
    expect(find.text('Próximos días (0)'), findsOneWidget);
  });

  testWidgets('recordatorios: avance, estados y botón grande', (tester) async {
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

    expect(find.text('Enviados 1 de 3'), findsOneWidget);
    expect(find.text('Enviar'), findsNWidgets(2));
    expect(find.text('Enviado'), findsOneWidget);
    expect(find.text('Sin WhatsApp'), findsOneWidget);
    expect(find.text('Enviar recordatorios (2)'), findsOneWidget);
    // El aviso de hoy se programa con los que faltan enviar.
    expect(avisos.programaciones.last.pendientesHoy, 2);
  });

  testWidgets('cuando ya se envió todo dice "¡Listo!"', (tester) async {
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba(enviado: true)]);
    await montar(tester);

    expect(find.text('¡Listo! Ya les recordaste a todos.'), findsOneWidget);
    expect(find.byKey(const Key('enviar-recordatorios')), findsNothing);
  });

  testWidgets('"Enviar" abre WhatsApp y registra al confirmar', (tester) async {
    when(() => recordatorios.pendientes()).thenAnswer(
      (_) async => [mensajePrueba(), mensajePrueba(controlId: 'c-2')],
    );
    await montar(tester);

    await tester.tap(find.text('Enviar').first);
    await tester.pumpAndSettle();

    expect(whatsapp.abiertos, ['https://wa.me/51987654321?text=Hola']);
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    verify(
      () => recordatorios.registrarEnvio('c-1', TipoRecordatorio.previo),
    ).called(1);
    expect(find.text('Mensaje registrado'), findsOneWidget);
  });

  testWidgets('si responde "No", no se registra', (tester) async {
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba()]);
    await montar(tester);

    await tester.tap(find.text('Enviar recordatorio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    verifyNever(() => recordatorios.registrarEnvio(any(), any()));
  });

  testWidgets('el botón grande envía uno por uno y "Detener" corta', (
    tester,
  ) async {
    when(() => recordatorios.pendientes()).thenAnswer(
      (_) async => [
        mensajePrueba(controlId: 'c-1', paciente: 'Juan Pérez'),
        mensajePrueba(controlId: 'c-2', paciente: 'Ana Ríos'),
        mensajePrueba(controlId: 'c-3', paciente: 'Eva Paz'),
      ],
    );
    // Pantalla alta, como un celular: el botón queda a la vista.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await montar(tester);

    await tester.tap(find.text('Enviar recordatorios (3)'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se envió el mensaje a Juan Pérez?'), findsOneWidget);
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();
    expect(find.text('¿Se envió el mensaje a Ana Ríos?'), findsOneWidget);
    await tester.tap(find.text('Detener'));
    await tester.pumpAndSettle();

    expect(whatsapp.abiertos, hasLength(2));
    verify(() => recordatorios.registrarEnvio('c-1', any())).called(1);
    verifyNever(() => recordatorios.registrarEnvio('c-2', any()));
    expect(find.text('1 recordatorio enviado'), findsOneWidget);
  });

  testWidgets(
    'el saludo "…, Dr. Marco" va en una sola línea en pantalla angosta '
    'y con letra al 200 %',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await montar(tester);

      final saludo = find.textContaining(', Dr. Marco');
      expect(saludo, findsOneWidget);
      expect(tester.widget<Text>(saludo).maxLines, 1);
      expect(
        find.ancestor(of: saludo, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
      // Una sola línea: el alto del texto es el de una línea de su estilo.
      final parrafo = tester.renderObject<RenderParagraph>(saludo);
      expect(parrafo.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('"Hoy vienen" lista los citados de hoy', (tester) async {
    // Pantalla alta, como un celular: todas las tarjetas a la vista.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => controles.agenda()).thenAnswer(
      (_) async => [
        controlPrueba(
          id: 'c-hoy',
          pacienteId: 'p-rosa',
          paciente: paciente('Rosa Quispe'),
          fecha: Fechas.hoy(),
        ),
        controlPrueba(
          id: 'c-luego',
          pacienteId: 'p-juan',
          paciente: paciente('Juan Pérez'),
          fecha: Fechas.hoy().add(const Duration(days: 3)),
        ),
      ],
    );
    await montar(tester);

    expect(find.text('Rosa Quispe'), findsOneWidget);
    // Los de otros días quedan plegados en "Próximos días".
    expect(find.text('Juan Pérez'), findsNothing);
    expect(find.text('Próximos días (1)'), findsOneWidget);

    await tester.tap(find.text('Próximos días (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Juan Pérez'), findsOneWidget);
  });

  testWidgets('cuando el servidor termina de despertar, recarga sola lo que '
      'falló mientras tanto', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(
      () => salud.servidorDisponible(),
    ).thenAnswer((_) => Future.delayed(const Duration(seconds: 2), () => true));
    var llamadas = 0;
    when(() => controles.agenda()).thenAnswer((_) async {
      llamadas++;
      if (llamadas == 1) throw Exception('el servidor estaba dormido');
      return [
        controlPrueba(
          id: 'c-hoy',
          pacienteId: 'p-rosa',
          paciente: paciente('Rosa Quispe'),
          fecha: Fechas.hoy(),
        ),
      ];
    });

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Rosa Quispe'), findsNothing);

    // El servidor responde: sin tocar "Reintentar", la agenda se vuelve a pedir.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(llamadas, 2);
    expect(find.text('Rosa Quispe'), findsOneWidget);
  });

  testWidgets('"No vinieron" distingue a los marcados "No vino"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(() => recordatorios.seguimientos()).thenAnswer(
      (_) async => [
        mensajePrueba(
          controlId: 'c-a',
          paciente: 'Ana Ríos',
          tipo: TipoRecordatorio.seguimiento,
          estado: EstadoControl.noAsistio,
        ),
        mensajePrueba(
          controlId: 'c-b',
          paciente: 'Luis Soto',
          tipo: TipoRecordatorio.seguimiento,
          diasAtraso: 3,
        ),
      ],
    );
    await montar(tester);

    expect(find.text('Brackets (ortodoncia) · no vino hoy'), findsOneWidget);
    expect(find.text('Brackets (ortodoncia) · hace 3 días'), findsOneWidget);
  });

  testWidgets(
    'en "No vinieron", tras escribirle se le pone la fecha ahí mismo',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final hoy = Fechas.hoy();
      when(() => recordatorios.seguimientos()).thenAnswer(
        (_) async => [
          mensajePrueba(
            controlId: 'c-a',
            paciente: 'Ana Ríos',
            tipo: TipoRecordatorio.seguimiento,
            enviado: true,
            estado: EstadoControl.noAsistio,
            diasAtraso: 2,
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
        (_) async =>
            controlPrueba(id: 'c-b', fecha: hoy.add(const Duration(days: 1))),
      );
      await montar(tester);

      expect(
        find.text(
          'Brackets (ortodoncia) · no vino hace 2 días · mensaje enviado',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Poner fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mañana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No, recordárselo'));
      await tester.pumpAndSettle();

      verify(
        () => controles.reprogramar(
          'c-a',
          hoy.add(const Duration(days: 1)),
          null,
          confirmado: false,
        ),
      ).called(1);
    },
  );

  testWidgets(
    'en "Recordatorios de mañana", al que ya confirmó no se le envía',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      when(() => recordatorios.pendientes()).thenAnswer(
        (_) async => [
          mensajePrueba(controlId: 'c-1', paciente: 'Juan Pérez'),
          mensajePrueba(
            controlId: 'c-2',
            paciente: 'Ana Ríos',
            estado: EstadoControl.confirmado,
          ),
        ],
      );
      await montar(tester);

      // Ana se ve en la lista (para saber quién viene), pero como "Confirmó".
      expect(find.text('Ana Ríos'), findsOneWidget);
      expect(find.text('Confirmó'), findsOneWidget);
      // Solo Juan cuenta para enviar.
      expect(find.text('Enviar recordatorio'), findsOneWidget);
      expect(find.text('Enviar recordatorios (2)'), findsNothing);
    },
  );

  testWidgets('"No vinieron" ofrece escribirles', (tester) async {
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

    expect(find.text('Brackets (ortodoncia) · hace 3 días'), findsOneWidget);
    await tester.ensureVisible(find.text('Escribirle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escribirle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, se envió'));
    await tester.pumpAndSettle();

    verify(
      () => recordatorios.registrarEnvio('c-v', TipoRecordatorio.seguimiento),
    ).called(1);
  });

  testWidgets('si WhatsApp no abre, avisa y no pregunta', (tester) async {
    whatsapp = EnvioWhatsappFalso(exito: false);
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => [mensajePrueba()]);
    await montar(tester);

    await tester.tap(find.text('Enviar recordatorio'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo abrir WhatsApp.'), findsOneWidget);
    expect(find.textContaining('¿Se envió'), findsNothing);
  });
}
