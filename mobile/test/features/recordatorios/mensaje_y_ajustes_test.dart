import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/avisos/avisos_diarios.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/ajustes/presentation/ajustes_page.dart';
import 'package:gerenz_dent/features/auth/data/almacen_sesion.dart';
import 'package:gerenz_dent/features/auth/domain/sesion.dart';
import 'package:gerenz_dent/features/controles/domain/control.dart';
import 'package:gerenz_dent/features/recordatorios/domain/mensaje_recordatorio.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_PE'));

  test('lee el mensaje armado por la API', () {
    final m = MensajeRecordatorio.fromJson({
      'controlId': 'c-1',
      'tipo': 'PREVIO',
      'fecha': '2026-11-11',
      'hora': '19:30:00',
      'estado': 'RECORDADO',
      'diasAtraso': 0,
      'tratamiento': 'Brackets (ortodoncia)',
      'pacienteId': 'p-1',
      'pacienteNombre': 'Juan Pérez',
      'pacienteWhatsapp': '+51987654321',
      'consienteWhatsapp': true,
      'mensaje': 'Hola Juan 👋',
      'enlace': 'https://wa.me/51987654321?text=Hola',
      'enviado': true,
      'ultimoEnvio': '2026-11-10T22:31:00Z',
    });

    expect(m.tipo, TipoRecordatorio.previo);
    expect(m.hora, const TimeOfDay(hour: 19, minute: 30));
    expect(m.estado, EstadoControl.recordado);
    expect(m.sePuedeEnviar, isTrue);
    expect(m.porEnviar, isFalse); // ya enviado
    expect(m.ultimoEnvio, isNotNull);
  });

  test('sin consentimiento no se puede enviar', () {
    final m = mensajePrueba(consiente: false);
    expect(m.sePuedeEnviar, isFalse);
    expect(m.porEnviar, isFalse);
  });

  test('el usuario guarda la hora del aviso y usa 4:30 p. m. por defecto', () {
    final sinHora = Usuario.fromJson({
      'id': 'u',
      'nombre': 'Dr. X',
      'email': 'x@y.z',
    });
    expect(sinHora.horaNotificacion, const TimeOfDay(hour: 16, minute: 30));

    final ida = sinHora.conHora(const TimeOfDay(hour: 17, minute: 45)).toJson();
    expect(Usuario.fromJson(ida).horaNotificacion.minute, 45);
  });

  group('Ajustes', () {
    late ServicioAvisosFalso avisos;

    Future<void> montar(WidgetTester tester) async {
      avisos = ServicioAvisosFalso();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            servicioAvisosProvider.overrideWithValue(avisos),
            almacenSesionProvider.overrideWithValue(
              AlmacenSesionMemoria(sesionPrueba()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.claro, home: const AjustesPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la hora del aviso diario', (tester) async {
      await montar(tester);
      expect(find.text('Todos los días a las 4:30 p. m.'), findsOneWidget);
    });

    testWidgets('ya no ofrece "Probar aviso"', (tester) async {
      await montar(tester);
      expect(find.text('Probar aviso'), findsNothing);
    });
  });
}
