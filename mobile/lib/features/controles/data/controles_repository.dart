import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/control.dart';

/// Acceso a `/api/v1/controles`. Todos los errores salen como [ApiError].
class ControlesRepository {
  ControlesRepository(this._dio);

  final Dio _dio;

  Future<Control> agendar(NuevoControl datos) => _llamar(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/api/v1/controles',
      data: datos.toJson(),
    );
    return Control.fromJson(r.data!);
  });

  Future<CambioDeEstado> cambiarEstado(String id, EstadoControl estado) =>
      _llamar(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/controles/$id/estado',
          data: {'estado': estado.api},
        );
        final sugerida = r.data!['siguienteFechaSugerida'] as String?;
        return CambioDeEstado(
          control: Control.fromJson(r.data!['control'] as Map<String, dynamic>),
          siguienteFechaSugerida: sugerida == null
              ? null
              : DateTime.parse(sugerida),
        );
      });

  Future<Control> reprogramar(String id, DateTime fecha, TimeOfDay? hora) =>
      _llamar(() async {
        final r = await _dio.patch<Map<String, dynamic>>(
          '/api/v1/controles/$id/fecha',
          data: {
            'fecha': Fechas.aIso(fecha),
            if (hora != null) 'hora': Fechas.horaAApi(hora),
          },
        );
        return Control.fromJson(r.data!);
      });

  Future<List<Control>> historial(String pacienteId) =>
      _lista('/api/v1/pacientes/$pacienteId/controles');

  /// Con [cerrados] (calendario) también trae los que asistieron o no
  /// vinieron; los cancelados nunca.
  Future<List<Control>> agenda({
    DateTime? desde,
    DateTime? hasta,
    bool cerrados = false,
  }) => _lista('/api/v1/controles', {
    if (desde != null) 'desde': Fechas.aIso(desde),
    if (hasta != null) 'hasta': Fechas.aIso(hasta),
    if (cerrados) 'cerrados': 'true',
  });

  Future<List<Control>> vencidos() => _lista('/api/v1/controles/vencidos');

  /// Fecha sugerida según el tratamiento y la edad del paciente (o `null`).
  Future<DateTime?> sugerencia(String pacienteId, String tratamientoId) =>
      _llamar(() async {
        final r = await _dio.get<Map<String, dynamic>>(
          '/api/v1/controles/sugerencia',
          queryParameters: {
            'pacienteId': pacienteId,
            'tratamientoId': tratamientoId,
          },
        );
        final fecha = r.data!['fecha'] as String?;
        return fecha == null ? null : DateTime.parse(fecha);
      });

  Future<List<Control>> _lista(String ruta, [Map<String, dynamic>? query]) =>
      _llamar(() async {
        final r = await _dio.get<List<dynamic>>(ruta, queryParameters: query);
        return r.data!
            .map((e) => Control.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<T> _llamar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final controlesRepositoryProvider = Provider<ControlesRepository>(
  (ref) => ControlesRepository(ref.watch(dioProvider)),
);
