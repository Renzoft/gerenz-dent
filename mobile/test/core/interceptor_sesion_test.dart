import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerenz_dent/core/network/interceptor_sesion.dart';
import 'package:gerenz_dent/features/auth/domain/sesion.dart';

import '../helpers/fakes.dart';

/// Servidor falso: responde según el token que llega en Authorization.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.responder);

  final ResponseBody Function(RequestOptions opciones) responder;
  final tokensRecibidos = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    tokensRecibidos.add(options.headers['Authorization'] as String?);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int estado, Object cuerpo) => ResponseBody.fromString(
  jsonEncode(cuerpo),
  estado,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late AlmacenSesionMemoria almacen;
  late _AdaptadorFalso adaptador;
  late Dio dio;
  late int refrescos;
  late int expiraciones;
  late Future<Sesion> Function(String) refrescar;

  void construir() {
    dio = Dio(BaseOptions(baseUrl: 'http://api'))
      ..httpClientAdapter = adaptador;
    final sinInterceptor = Dio(BaseOptions(baseUrl: 'http://api'))
      ..httpClientAdapter = adaptador;
    dio.interceptors.add(
      InterceptorSesion(
        almacen: almacen,
        refrescar: (t) {
          refrescos++;
          return refrescar(t);
        },
        reintentar: sinInterceptor.fetch,
        alExpirar: () async => expiraciones++,
      ),
    );
  }

  setUp(() {
    almacen = AlmacenSesionMemoria(sesionPrueba(access: 'viejo'));
    refrescos = 0;
    expiraciones = 0;
    refrescar = (_) async =>
        sesionPrueba(access: 'nuevo', refresh: 'refresh-2');
    // El servidor acepta solo el token "nuevo".
    adaptador = _AdaptadorFalso(
      (o) => o.headers['Authorization'] == 'Bearer nuevo'
          ? _json(200, {'ok': true})
          : _json(401, {'detail': 'No autenticado'}),
    );
    construir();
  });

  test('agrega el access token guardado a cada petición', () async {
    almacen.sesion = sesionPrueba(access: 'nuevo');

    await dio.get<void>('/api/v1/pacientes');

    expect(adaptador.tokensRecibidos, ['Bearer nuevo']);
  });

  test('ante un 401 renueva la sesión una vez y reintenta', () async {
    final r = await dio.get<Map<String, dynamic>>('/api/v1/pacientes');

    expect(r.data, {'ok': true});
    expect(refrescos, 1);
    expect(adaptador.tokensRecibidos, ['Bearer viejo', 'Bearer nuevo']);
    expect(almacen.sesion!.refreshToken, 'refresh-2');
    expect(expiraciones, 0);
  });

  test('si el refresh falla, cierra la sesión y propaga el error', () async {
    refrescar = (_) async => throw Exception('refresh vencido');

    await expectLater(
      dio.get<void>('/api/v1/pacientes'),
      throwsA(isA<DioException>()),
    );
    expect(expiraciones, 1);
  });

  test('no entra en bucle si el reintento también responde 401', () async {
    adaptador = _AdaptadorFalso((_) => _json(401, {'detail': 'No'}));
    construir();

    await expectLater(
      dio.get<void>('/api/v1/pacientes'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'estado',
          401,
        ),
      ),
    );
    expect(refrescos, 1);
    expect(adaptador.tokensRecibidos.length, 2);
  });

  test('otros errores (p. ej. 404) pasan sin renovar la sesión', () async {
    adaptador = _AdaptadorFalso((_) => _json(404, {'detail': 'No encontrado'}));
    construir();

    await expectLater(dio.get<void>('/x'), throwsA(isA<DioException>()));
    expect(refrescos, 0);
  });
}
