import 'package:dio/dio.dart';

/// Error de la API traducido a algo que se puede mostrar al doctor.
///
/// La API responde errores en formato RFC 9457 (Problem Details):
/// `{"status": 400, "detail": "...", "errores": {"campo": "mensaje"}}`.
class ApiError implements Exception {
  const ApiError({
    required this.mensaje,
    this.estado,
    this.errores = const {},
    this.datos = const {},
  });

  /// Construye un [ApiError] desde cualquier error (Dio, red, inesperado).
  factory ApiError.desde(Object error) {
    if (error is ApiError) return error;
    if (error is! DioException) {
      return const ApiError(mensaje: 'Ocurrió un error inesperado.');
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiError(
          mensaje:
              'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        );
      case DioExceptionType.connectionError:
        return const ApiError(
          mensaje: 'No se pudo conectar. Revisa tu internet.',
        );
      default:
        break;
    }
    final respuesta = error.response;
    final cuerpo = respuesta?.data;
    if (cuerpo is Map<String, dynamic>) {
      final errores = <String, String>{};
      final crudos = cuerpo['errores'];
      if (crudos is Map) {
        crudos.forEach((k, v) => errores['$k'] = '$v');
      }
      return ApiError(
        mensaje: (cuerpo['detail'] as String?) ?? 'Ocurrió un error.',
        estado: respuesta?.statusCode,
        errores: errores,
        datos: cuerpo,
      );
    }
    return ApiError(
      mensaje: 'Ocurrió un error (código ${respuesta?.statusCode ?? '?'}).',
      estado: respuesta?.statusCode,
    );
  }

  final String mensaje;
  final int? estado;

  /// Errores por campo (validación del formulario).
  final Map<String, String> errores;

  /// Cuerpo completo del error (p. ej. `pacienteExistenteId` en un 409).
  final Map<String, dynamic> datos;

  bool get esConflicto => estado == 409;
  bool get esNoAutenticado => estado == 401;

  @override
  String toString() => mensaje;
}
