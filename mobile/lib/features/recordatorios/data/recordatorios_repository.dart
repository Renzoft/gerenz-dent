import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/mensaje_recordatorio.dart';

/// Acceso a `/api/v1/recordatorios` y al registro de envíos.
class RecordatoriosRepository {
  RecordatoriosRepository(this._dio);

  final Dio _dio;

  /// Recordatorios de una fecha (por defecto, mañana).
  Future<List<MensajeRecordatorio>> pendientes({DateTime? fecha}) => _lista(
    '/api/v1/recordatorios/pendientes',
    {if (fecha != null) 'fecha': Fechas.aIso(fecha)},
  );

  /// Seguimientos de controles vencidos.
  Future<List<MensajeRecordatorio>> seguimientos() =>
      _lista('/api/v1/recordatorios/seguimientos');

  /// El doctor confirma que envió el mensaje.
  Future<void> registrarEnvio(String controlId, TipoRecordatorio tipo) async {
    try {
      await _dio.post<void>(
        '/api/v1/controles/$controlId/recordatorios',
        data: {'tipo': tipo.api},
      );
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  /// Hora del aviso diario (HU-20).
  Future<TimeOfDay> cambiarHoraAviso(TimeOfDay hora) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/auth/yo',
        data: {'horaNotificacion': Fechas.horaAApi(hora)},
      );
      return Fechas.horaDesdeApi(r.data!['horaNotificacion'] as String?) ??
          hora;
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  Future<List<MensajeRecordatorio>> _lista(
    String ruta, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      final r = await _dio.get<List<dynamic>>(ruta, queryParameters: query);
      return r.data!
          .map((e) => MensajeRecordatorio.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final recordatoriosRepositoryProvider = Provider<RecordatoriosRepository>(
  (ref) => RecordatoriosRepository(ref.watch(dioProvider)),
);
