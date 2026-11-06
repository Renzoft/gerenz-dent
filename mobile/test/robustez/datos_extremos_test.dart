// Robustez: cada pantalla con el peor caso realista (nada se desborda ni se corta).
//
// Datos ficticios, con los límites reales del esquema (backend V1–V8):
// nombres de 80 caracteres, notas de 140, alergias de 200 y montos grandes.
// Se monta cada pantalla a 320 dp con letra normal y a 360 dp con la letra
// del sistema al 200 %. Flutter marca como error cualquier desborde
// (RenderFlex overflow), así que una prueba en verde = nada se corta.
import 'package:flutter/material.dart';
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
import 'package:gerenz_dent/features/controles/presentation/agendar_control_sheet.dart';
import 'package:gerenz_dent/features/cuenta/data/cuenta_repository.dart';
import 'package:gerenz_dent/features/cuenta/domain/cuenta.dart';
import 'package:gerenz_dent/features/cuenta/presentation/deudas_page.dart';
import 'package:gerenz_dent/features/cuenta/presentation/registrar_pago_sheet.dart';
import 'package:gerenz_dent/features/inicio/data/salud_repository.dart';
import 'package:gerenz_dent/features/inicio/presentation/inicio_page.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/domain/paciente.dart';
import 'package:gerenz_dent/features/pacientes/presentation/paciente_detalle_page.dart';
import 'package:gerenz_dent/features/pacientes/presentation/pacientes_page.dart';
import 'package:gerenz_dent/features/recordatorios/data/recordatorios_repository.dart';
import 'package:gerenz_dent/features/recordatorios/domain/mensaje_recordatorio.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:gerenz_dent/features/tratamientos/domain/tratamiento.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class _SaludFalsa extends Mock implements SaludRepository {}

class _PerfilFalso extends Mock implements PerfilRepository {}

// ---------------------------------------------------------------------------
// Peor caso (ficticio)
// ---------------------------------------------------------------------------

/// 80 caracteres: el máximo de `paciente.nombre` (varchar 80).
const nombreMaximo =
    'María de los Ángeles Fernández-Villacorta Huamaní Quispe de la Torre y Santist';
const nombreLargo = 'José Antonio Ñahui Condori de Villanueva';
const nombreCorto = 'Jo';

/// Tratamiento con nombre largo (catálogo editable, varchar 80).
const tratamientoLargo = Tratamiento(
  id: 't-largo',
  nombre: 'Endodoncia de molar con reconstrucción en resina compuesta',
  tipoPrecio: TipoPrecio.fijo,
  precioBase: 12500,
);

/// 140 caracteres: el máximo de `control.nota`.
const notaMaxima =
    'Traer radiografía panorámica reciente. Paciente con ansiedad: explicar cada '
    'paso. Revisar sensibilidad en pieza 36 y cambiar ligas de colo';

/// 200 caracteres: el máximo de `paciente.alergias`.
const alergiaMaxima =
    'Penicilina y amoxicilina (urticaria), látex (dermatitis de contacto), '
    'ibuprofeno y AINEs (broncoespasmo), lidocaína con epinefrina: usar '
    'mepivacaína sin vasoconstrictor. Confirmar antes de cada pr';

MensajeRecordatorio _mensaje(
  int i, {
  String nombre = nombreLargo,
  String tratamiento = 'Endodoncia de molar con reconstrucción en resina',
  bool enviado = false,
  bool consiente = true,
  TipoRecordatorio tipo = TipoRecordatorio.previo,
  int diasAtraso = 0,
}) => MensajeRecordatorio(
  controlId: 'c-$i',
  tipo: tipo,
  fecha: Fechas.hoy().add(const Duration(days: 1)),
  hora: const TimeOfDay(hour: 19, minute: 45),
  estado: enviado ? EstadoControl.recordado : EstadoControl.pendiente,
  diasAtraso: diasAtraso,
  tratamiento: tratamiento,
  pacienteId: 'p-$i',
  pacienteNombre: nombre,
  pacienteWhatsapp: '+51987654321',
  consienteWhatsapp: consiente,
  mensaje: 'Hola',
  enlace: consiente ? 'https://wa.me/51987654321?text=Hola' : null,
  enviado: enviado,
);

/// 15 citados para mañana (el doble de una semana normal del consultorio),
/// mezclando los casos en las primeras filas.
final recordatoriosExtremos = [
  _mensaje(0, nombre: nombreMaximo),
  _mensaje(1, nombre: nombreCorto, enviado: true),
  _mensaje(2, consiente: false),
  for (var i = 3; i < 15; i++) _mensaje(i, enviado: i.isEven),
];

final seguimientosExtremos = [
  _mensaje(
    20,
    nombre: nombreMaximo,
    tipo: TipoRecordatorio.seguimiento,
    diasAtraso: 365,
  ),
  _mensaje(21, tipo: TipoRecordatorio.seguimiento, diasAtraso: 1),
];

PacienteDelControl _pdc(String nombre) =>
    PacienteDelControl(id: 'p-x', nombre: nombre, whatsapp: '+51987654321');

final agendaExtrema = [
  Control(
    id: 'h-1',
    pacienteId: 'p-1',
    fecha: Fechas.hoy(),
    hora: const TimeOfDay(hour: 21, minute: 30),
    estado: EstadoControl.confirmado,
    tratamientoId: tratamientoLargo.id,
    tratamientoNombre: tratamientoLargo.nombre,
    paciente: _pdc(nombreMaximo),
  ),
  for (var i = 1; i < 8; i++)
    Control(
      id: 'p-$i',
      pacienteId: 'p-$i',
      fecha: Fechas.hoy().add(Duration(days: i)),
      estado: EstadoControl.pendiente,
      tratamientoId: tratamientoLargo.id,
      tratamientoNombre: tratamientoLargo.nombre,
      paciente: _pdc(i.isEven ? nombreLargo : nombreCorto),
    ),
];

final controlesFicha = [
  Control(
    id: 'f-1',
    pacienteId: 'p-1',
    fecha: Fechas.hoy().subtract(const Duration(days: 400)),
    hora: const TimeOfDay(hour: 20, minute: 15),
    estado: EstadoControl.recordado,
    vencido: true,
    diasAtraso: 400,
    nota: notaMaxima,
    tratamientoId: tratamientoLargo.id,
    tratamientoNombre: tratamientoLargo.nombre,
  ),
  Control(
    id: 'f-2',
    pacienteId: 'p-1',
    fecha: Fechas.hoy().add(const Duration(days: 180)),
    estado: EstadoControl.confirmado,
    tratamientoId: 't-brackets',
    tratamientoNombre: 'Brackets (ortodoncia)',
  ),
  for (final e in [
    EstadoControl.asistio,
    EstadoControl.noAsistio,
    EstadoControl.cancelado,
  ])
    Control(
      id: 'h-${e.api}',
      pacienteId: 'p-1',
      fecha: Fechas.hoy().subtract(const Duration(days: 30)),
      estado: e,
      tratamientoId: tratamientoLargo.id,
      tratamientoNombre: tratamientoLargo.nombre,
    ),
];

const cuentaExtrema = CuentaPaciente(
  deuda: 125430.75,
  planes: [
    CuentaPlan(
      planId: 'pl-1',
      tratamientoId: 't-largo',
      tratamientoNombre:
          'Endodoncia de molar con reconstrucción en resina compuesta',
      piezas: 28,
      activo: true,
      totalCargos: 350000,
      totalPagos: 224569.25,
      saldo: 125430.75,
    ),
    CuentaPlan(
      planId: 'pl-2',
      tratamientoId: 't-brackets',
      tratamientoNombre: 'Brackets (ortodoncia)',
      activo: true,
      totalCargos: 2900,
      totalPagos: 2900,
      saldo: 0,
    ),
  ],
);

final deudasExtremas = ResumenDeudas(
  total: 1254307.5,
  pacientes: [
    const DeudaPaciente(
      pacienteId: 'p-1',
      nombre: nombreMaximo,
      whatsapp: '+51987654321',
      deuda: 1125430.75,
      archivado: true,
    ),
    const DeudaPaciente(
      pacienteId: 'p-2',
      nombre: nombreCorto,
      whatsapp: '+51987654321',
      deuda: 0.5,
    ),
    for (var i = 3; i < 40; i++)
      DeudaPaciente(
        pacienteId: 'p-$i',
        nombre: nombreLargo,
        whatsapp: '+51987654321',
        deuda: 3500.0 * i,
      ),
  ],
);

final pacientesExtremos = [
  const Paciente(
    id: 'p-1',
    nombre: nombreMaximo,
    whatsapp: '+51987654321',
    alergias: alergiaMaxima,
  ),
  const Paciente(id: 'p-2', nombre: nombreCorto, whatsapp: '+51912345678'),
  for (var i = 3; i < 60; i++)
    Paciente(id: 'p-$i', nombre: nombreLargo, whatsapp: '+51955111222'),
];

// ---------------------------------------------------------------------------
// Montaje
// ---------------------------------------------------------------------------

typedef _Config = ({String nombre, Size tamano, double escala});

const List<_Config> _configs = [
  (nombre: '320 dp, letra 100 %', tamano: Size(320, 640), escala: 1.0),
  (nombre: '360 dp, letra 200 %', tamano: Size(360, 780), escala: 2.0),
];

void main() {
  late _SaludFalsa salud;
  late ControlesRepositoryFalso controles;
  late RecordatoriosRepositoryFalso recordatorios;
  late PacientesRepositoryFalso pacientes;
  late CuentaRepositoryFalso cuenta;
  late TratamientosRepositoryFalso tratamientos;
  late _PerfilFalso perfil;

  setUpAll(() async {
    await initializeDateFormatting('es_PE');
    registerFallbackValue(TipoRecordatorio.previo);
  });

  setUp(() {
    salud = _SaludFalsa();
    controles = ControlesRepositoryFalso();
    recordatorios = RecordatoriosRepositoryFalso();
    pacientes = PacientesRepositoryFalso();
    cuenta = CuentaRepositoryFalso();
    tratamientos = TratamientosRepositoryFalso();
    perfil = _PerfilFalso();

    when(() => salud.servidorDisponible()).thenAnswer((_) async => true);
    when(() => controles.agenda()).thenAnswer((_) async => agendaExtrema);
    when(
      () => controles.historial(any()),
    ).thenAnswer((_) async => controlesFicha);
    when(
      () => recordatorios.pendientes(),
    ).thenAnswer((_) async => recordatoriosExtremos);
    when(
      () => recordatorios.seguimientos(),
    ).thenAnswer((_) async => seguimientosExtremos);
    when(() => perfil.yo()).thenAnswer((_) async => usuarioPrueba);
    when(
      () => pacientes.listar(
        texto: any(named: 'texto'),
        archivados: any(named: 'archivados'),
        pagina: any(named: 'pagina'),
      ),
    ).thenAnswer(
      (_) async => Pagina(
        contenido: pacientesExtremos,
        pagina: 0,
        totalElementos: 1284,
        totalPaginas: 22,
      ),
    );
    when(() => pacientes.obtener(any())).thenAnswer(
      (_) async => const Paciente(
        id: 'p-1',
        nombre: nombreMaximo,
        whatsapp: '+51987654321',
        edad: 120,
        alergias: alergiaMaxima,
        nota: notaMaxima,
        consienteWhatsapp: false,
        archivado: true,
      ),
    );
    when(() => cuenta.cuenta(any())).thenAnswer((_) async => cuentaExtrema);
    when(() => cuenta.deudas()).thenAnswer((_) async => deudasExtremas);
    when(
      () => tratamientos.listar(),
    ).thenAnswer((_) async => [tratamientoLargo, bracketsPrueba]);
  });

  Future<void> montar(WidgetTester tester, _Config c, Widget pantalla) async {
    tester.view.physicalSize = c.tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saludRepositoryProvider.overrideWithValue(salud),
          controlesRepositoryProvider.overrideWithValue(controles),
          recordatoriosRepositoryProvider.overrideWithValue(recordatorios),
          pacientesRepositoryProvider.overrideWithValue(pacientes),
          cuentaRepositoryProvider.overrideWithValue(cuenta),
          tratamientosRepositoryProvider.overrideWithValue(tratamientos),
          perfilRepositoryProvider.overrideWithValue(perfil),
          servicioAvisosProvider.overrideWithValue(ServicioAvisosFalso()),
          envioWhatsappProvider.overrideWithValue(EnvioWhatsappFalso()),
          almacenSesionProvider.overrideWithValue(
            AlmacenSesionMemoria(sesionPrueba()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.claro,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(c.escala)),
            child: child!,
          ),
          home: pantalla,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Recorre la pantalla de arriba abajo para que se construya todo.
  Future<void> recorrer(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
  }

  Future<void> volverArriba(WidgetTester tester, String pestana) async {
    for (var i = 0; i < 30 && find.text(pestana).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  // Guías de accesibilidad de Flutter (Android): áreas táctiles ≥ 48 dp,
  // controles con etiqueta y contraste de texto, en un celular típico.
  group('Accesibilidad', () {
    const celular = (nombre: 'celular', tamano: Size(392, 850), escala: 1.0);
    final pantallas = <String, Widget Function()>{
      'Inicio': () => const InicioPage(),
      'Pacientes': () => const PacientesPage(),
      'Ficha': () => const PacienteDetallePage(pacienteId: 'p-1'),
      'Deudas': () => const DeudasPage(),
    };
    for (final MapEntry(key: nombre, value: pantalla) in pantallas.entries) {
      testWidgets('$nombre cumple las guías', (tester) async {
        final semantica = tester.ensureSemantics();
        await montar(tester, celular, pantalla());
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    }
  });

  for (final c in _configs) {
    group(c.nombre, () {
      testWidgets('Inicio: 15 recordatorios, nombres de 80 y 2 letras', (
        tester,
      ) async {
        await montar(tester, c, const InicioPage());
        expect(find.text(nombreMaximo), findsWidgets);
        await tester.tap(find.textContaining('Próximos días'));
        await tester.pumpAndSettle();
        await recorrer(tester);
      });

      testWidgets('Pacientes: 1,284 pacientes y alergia', (tester) async {
        await montar(tester, c, const PacientesPage());
        expect(find.text('1284 pacientes'), findsOneWidget);
        await recorrer(tester);
      });

      testWidgets('Ficha: todo al máximo, en sus 3 pestañas', (tester) async {
        await montar(tester, c, const PacienteDetallePage(pacienteId: 'p-1'));
        await recorrer(tester);
        await volverArriba(tester, 'Pagos');
        await tester.tap(find.text('Pagos'));
        await tester.pumpAndSettle();
        await recorrer(tester);
        await volverArriba(tester, 'Datos');
        await tester.tap(find.text('Datos'));
        await tester.pumpAndSettle();
        await recorrer(tester);
      });

      testWidgets('Deudas: S/ 1,254,307.50 y 39 pacientes', (tester) async {
        await montar(tester, c, const DeudasPage());
        expect(find.text('S/ 1,254,307.50'), findsOneWidget);
        await recorrer(tester);
      });

      testWidgets('Agendar control: tratamiento largo y cobro', (tester) async {
        when(() => cuenta.cuenta(any())).thenAnswer((_) async => cuentaVacia);
        await montar(
          tester,
          c,
          Scaffold(
            body: AgendarControlSheet(
              pacienteId: 'p-1',
              pacienteNombre: nombreMaximo,
              tratamientoInicial: tratamientoLargo.id,
              fechaInicial: Fechas.hoy().add(const Duration(days: 180)),
            ),
          ),
        );
        await recorrer(tester);
      });

      testWidgets('Registrar pago: deuda grande', (tester) async {
        await montar(
          tester,
          c,
          const Scaffold(
            body: RegistrarPagoSheet(
              planId: 'pl-1',
              tratamiento:
                  'Endodoncia de molar con reconstrucción en resina compuesta',
              saldo: 125430.75,
            ),
          ),
        );
        await tester.tap(find.text('Registrar pago').last);
        await tester.pumpAndSettle();
      });
    });
  }
}
