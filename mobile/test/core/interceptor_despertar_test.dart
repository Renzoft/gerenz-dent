import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/network/interceptor_despertar.dart';

/// Responde con los códigos de [codigos] en orden (el último se repite).
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.codigos);

  final List<int> codigos;
  int llamadas = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final codigo = codigos[llamadas.clamp(0, codigos.length - 1)];
    llamadas++;
    return ResponseBody.fromString(
      jsonEncode({'status': codigo == 200 ? 'UP' : 'DOWN'}),
      codigo,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  (Dio, _AdaptadorFalso) cliente(
    List<int> codigos, {
    Duration plazo = const Duration(seconds: 100),
    DateTime Function()? reloj,
  }) {
    final adaptador = _AdaptadorFalso(codigos);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adaptador;
    dio.interceptors.add(
      InterceptorDespertar(
        dio: dio,
        plazo: plazo,
        pausa: Duration.zero,
        reloj: reloj,
      ),
    );
    return (dio, adaptador);
  }

  test('una consulta se repite mientras el servidor despierta (503)', () async {
    final (dio, adaptador) = cliente([503, 502, 200]);

    final respuesta = await dio.get<Map<String, dynamic>>('/actuator/health');

    expect(respuesta.data?['status'], 'UP');
    expect(adaptador.llamadas, 3);
  });

  test('una escritura (POST) nunca se repite', () async {
    final (dio, adaptador) = cliente([503, 200]);

    await expectLater(
      dio.post<void>('/auth/login'),
      throwsA(isA<DioException>()),
    );
    expect(adaptador.llamadas, 1);
  });

  test('un error que no es del arranque (404) no se repite', () async {
    final (dio, adaptador) = cliente([404, 200]);

    await expectLater(
      dio.get<void>('/pacientes/x'),
      throwsA(isA<DioException>()),
    );
    expect(adaptador.llamadas, 1);
  });

  test('deja de reintentar al pasar el plazo', () async {
    var ahora = DateTime(2026, 11, 5, 17);
    final (dio, adaptador) = cliente(
      [503],
      plazo: const Duration(seconds: 10),
      // Cada consulta del reloj avanza 4 s.
      reloj: () => ahora = ahora.add(const Duration(seconds: 4)),
    );

    await expectLater(dio.get<void>('/salud'), throwsA(isA<DioException>()));
    expect(adaptador.llamadas, lessThan(4));
  });
}
