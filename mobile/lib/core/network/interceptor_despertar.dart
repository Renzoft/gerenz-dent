import 'dart:async';

import 'package:dio/dio.dart';

/// Reintenta solo las consultas (GET) cuando el servidor está despertando.
///
/// En el plan gratuito de Render la API se apaga tras 15 minutos sin uso y
/// tarda cerca de un minuto en volver. Mientras tanto, una petición puede
/// fallar por tiempo de espera, por conexión o con 502/503/504. En vez de
/// mostrar el error al doctor, se vuelve a intentar hasta [plazo] desde el
/// primer intento. Las escrituras (POST, PUT…) nunca se repiten.
class InterceptorDespertar extends Interceptor {
  InterceptorDespertar({
    required this.dio,
    this.plazo = const Duration(seconds: 100),
    this.pausa = const Duration(seconds: 3),
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  /// Cliente por el que se repite la petición (pasa otra vez por todos sus
  /// interceptores, así que el token se vuelve a poner).
  final Dio dio;

  /// Tiempo máximo, contado desde el primer intento, para seguir reintentando.
  final Duration plazo;

  /// Espera entre un intento y el siguiente.
  final Duration pausa;

  final DateTime Function() _reloj;

  static const _inicio = 'despertar_inicio';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.putIfAbsent(_inicio, () => _reloj());
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opciones = err.requestOptions;
    final inicio = opciones.extra[_inicio] as DateTime? ?? _reloj();
    final quedaTiempo = _reloj().difference(inicio) + pausa < plazo;
    if (!_esConsulta(opciones) ||
        !_esServidorDespertando(err) ||
        !quedaTiempo) {
      return handler.next(err);
    }
    await Future<void>.delayed(pausa);
    try {
      return handler.resolve(await dio.fetch<dynamic>(opciones));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  static bool _esConsulta(RequestOptions opciones) =>
      opciones.method.toUpperCase() == 'GET';

  static bool _esServidorDespertando(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final codigo = err.response?.statusCode;
        return codigo == 502 || codigo == 503 || codigo == 504;
      default:
        return false;
    }
  }
}
