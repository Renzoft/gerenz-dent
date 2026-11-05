import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/contactos/selector_contactos.dart';
import 'package:gerenz_dent/core/network/api_error.dart';
import 'package:gerenz_dent/core/theme/app_theme.dart';
import 'package:gerenz_dent/features/pacientes/data/pacientes_repository.dart';
import 'package:gerenz_dent/features/pacientes/presentation/paciente_form_page.dart';
import 'package:gerenz_dent/features/tratamientos/data/tratamientos_repository.dart';
import 'package:gerenz_dent/features/tratamientos/domain/tratamiento.dart';
import 'package:gerenz_dent/features/tratamientos/presentation/catalogo_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fakes.dart';

class _SelectorFalso implements SelectorContactos {
  _SelectorFalso(this.contacto);

  final ContactoElegido? contacto;

  @override
  Future<ContactoElegido?> elegirTelefono() async => contacto;
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const DatosTratamiento(nombre: '', tipoPrecio: TipoPrecio.fijo),
    );
  });

  group('Catálogo', () {
    late TratamientosRepositoryFalso repo;

    setUp(() {
      repo = TratamientosRepositoryFalso();
      when(() => repo.listar(todos: true)).thenAnswer(
        (_) async => [
          bracketsPrueba,
          puentePrueba,
          const Tratamiento(
            id: 't-x',
            nombre: 'Extracción dental',
            tipoPrecio: TipoPrecio.fijo,
            precioBase: 70,
            activo: false,
          ),
        ],
      );
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tratamientosRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(theme: AppTheme.claro, home: const CatalogoPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lista los tratamientos con su forma de cobro', (tester) async {
      await montar(tester);

      expect(
        find.text('S/ 500.00 + S/ 100.00 por control · control cada 30 días'),
        findsOneWidget,
      );
      expect(find.text('S/ 700.00 por pieza'), findsOneWidget);
      expect(find.text('S/ 70.00 · Inactivo'), findsOneWidget);
    });

    testWidgets('crea un tratamiento nuevo', (tester) async {
      when(
        () => repo.guardar(any(), id: any(named: 'id')),
      ).thenAnswer((_) async => puentePrueba);
      await montar(tester);

      await tester.tap(find.text('Tratamiento'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nombre-tratamiento')),
        'Curación con resina',
      );
      await tester.tap(find.text('Por pieza').last);
      await tester.enterText(find.byKey(const Key('precio-base')), '90');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final datos =
          verify(
                () => repo.guardar(captureAny(), id: any(named: 'id')),
              ).captured.single
              as DatosTratamiento;
      expect(datos.nombre, 'Curación con resina');
      expect(datos.tipoPrecio, TipoPrecio.porPieza);
      expect(datos.precioBase, 90);
      expect(datos.intervaloControlDias, isNull);
      expect(find.text('Catálogo actualizado'), findsOneWidget);
    });

    testWidgets('pide la cuota si se cobra inicial + mensual', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Tratamiento'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nombre-tratamiento')),
        'Ortodoncia',
      );
      await tester.tap(find.text('Inicial + mensual').last);
      await tester.pump();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Indica la cuota mensual'), findsOneWidget);
      verifyNever(() => repo.guardar(any(), id: any(named: 'id')));
    });

    testWidgets('muestra el error de la API (nombre repetido)', (tester) async {
      when(() => repo.guardar(any(), id: any(named: 'id'))).thenThrow(
        const ApiError(
          mensaje: 'Ya existe un tratamiento llamado "Extracción dental".',
          estado: 409,
        ),
      );
      await montar(tester);

      await tester.tap(find.text('Tratamiento'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nombre-tratamiento')),
        'Extracción dental',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ya existe un tratamiento'), findsOneWidget);
    });

    testWidgets('desactivar un tratamiento llama a la API', (tester) async {
      when(
        () => repo.cambiarActivo('t-brackets', activo: false),
      ).thenAnswer((_) async => bracketsPrueba);
      await montar(tester);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      verify(() => repo.cambiarActivo('t-brackets', activo: false)).called(1);
      expect(find.textContaining('ya no se ofrecerá'), findsOneWidget);
    });
  });

  group('Importar contacto (HU-07)', () {
    Future<void> montar(WidgetTester tester, ContactoElegido? contacto) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pacientesRepositoryProvider.overrideWithValue(
              PacientesRepositoryFalso(),
            ),
            selectorContactosProvider.overrideWithValue(
              _SelectorFalso(contacto),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.claro,
            home: const PacienteFormPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder campo(String etiqueta) =>
        find.widgetWithText(TextFormField, etiqueta);

    testWidgets('completa el número y el nombre desde la agenda', (
      tester,
    ) async {
      await montar(
        tester,
        const ContactoElegido(
          nombre: 'Rosa Quispe',
          telefono: '+51 955 111 222',
        ),
      );

      await tester.tap(find.byTooltip('Elegir de mis contactos'));
      await tester.pumpAndSettle();

      expect(find.text('+51 955 111 222'), findsOneWidget);
      expect(find.text('Rosa Quispe'), findsOneWidget);
    });

    testWidgets('no reemplaza un nombre ya escrito', (tester) async {
      await montar(
        tester,
        const ContactoElegido(nombre: 'Mamá Rosa', telefono: '955111222'),
      );

      await tester.enterText(campo('Nombre completo'), 'Rosa Quispe');
      await tester.tap(find.byTooltip('Elegir de mis contactos'));
      await tester.pumpAndSettle();

      expect(find.text('Rosa Quispe'), findsOneWidget);
      expect(find.text('Mamá Rosa'), findsNothing);
      expect(find.text('955111222'), findsOneWidget);
    });

    testWidgets('si cancela, no cambia nada', (tester) async {
      await montar(tester, null);

      await tester.tap(find.byTooltip('Elegir de mis contactos'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa el número de WhatsApp'), findsNothing);
    });
  });
}
