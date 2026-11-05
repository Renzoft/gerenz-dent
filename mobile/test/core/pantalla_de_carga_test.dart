import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/widgets/pantalla_de_carga.dart';

void main() {
  for (final tamano in const [Size(360, 800), Size(412, 915), Size(320, 640)]) {
    testWidgets('el logo y los textos quedan al centro exacto en '
        '${tamano.width.toInt()}×${tamano.height.toInt()}', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: PantallaDeCarga()));

      final logo = find.bySemanticsLabel(
        'GERENZ DENT, consultorio odontológico',
      );
      expect(logo, findsOneWidget);
      final centro = tester.getCenter(find.byType(Image));
      expect(centro.dx, closeTo(tamano.width / 2, 0.5));
      expect(centro.dy, closeTo(tamano.height / 2, 0.5));
    });
  }
}
