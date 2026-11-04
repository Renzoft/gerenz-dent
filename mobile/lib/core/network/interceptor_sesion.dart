import 'package:dio/dio.dart';

import '../../features/auth/data/almacen_sesion.dart';
import '../../features/auth/domain/sesion.dart';

/// Agrega el access token a cada petición y, si la API responde 401, renueva
/// la sesión con el refresh token **una sola vez** y reintenta la petición.
///
/// Es un [QueuedInterceptor]: si llegan varias respuestas 401 a la vez, se
/// procesan en fila y solo la primera renueva el token.
class InterceptorSesion extends QueuedInterceptor {
  InterceptorSesion({
    required this.almacen,
    required this.refrescar,
    required this.reintentar,
    required this.alExpirar,
  });

  final AlmacenSesion almacen;

  /// Llama a `/auth/refresh` (con un cliente sin este interceptor).
  final Future<Sesion> Function(String refreshToken) refrescar;

  /// Repite la petición original con el token nuevo.
  final Future<Response<dynamic>> Function(RequestOptions opciones) reintentar;

  /// Se ejecuta cuando la sesión ya no se puede renovar (ir al login).
  final Future<void> Function() alExpirar;

  static const _yaReintentado = 'sesion_reintentado';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final sesion = await almacen.leer();
    if (sesion != null) {
      options.headers['Authorization'] = 'Bearer ${sesion.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opciones = err.requestOptions;
    final es401 = err.response?.statusCode == 401;
    if (!es401 || opciones.extra[_yaReintentado] == true) {
      return handler.next(err);
    }

    final sesion = await almacen.leer();
    if (sesion == null) {
      await alExpirar();
      return handler.next(err);
    }

    // Otra petición en la fila ya renovó el token: solo reintentar.
    final tokenUsado = opciones.headers['Authorization'];
    final tokenActual = 'Bearer ${sesion.accessToken}';
    try {
      if (tokenUsado == tokenActual) {
        final nueva = await refrescar(sesion.refreshToken);
        await almacen.guardar(nueva);
        opciones.headers['Authorization'] = 'Bearer ${nueva.accessToken}';
      } else {
        opciones.headers['Authorization'] = tokenActual;
      }
      opciones.extra[_yaReintentado] = true;
      return handler.resolve(await reintentar(opciones));
    } on DioException catch (e) {
      return handler.next(e);
    } catch (_) {
      // El refresh token venció o fue revocado.
      await alExpirar();
      return handler.next(err);
    }
  }
}
