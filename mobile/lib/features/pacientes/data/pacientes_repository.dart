import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/paciente.dart';

/// Acceso a `/api/v1/pacientes`. Todos los errores salen como [ApiError].
class PacientesRepository {
  PacientesRepository(this._dio);

  final Dio _dio;
  static const _ruta = '/api/v1/pacientes';
  static const tamanoPagina = 30;

  Future<Pagina<Paciente>> listar({
    String texto = '',
    bool archivados = false,
    int pagina = 0,
  }) => _llamar(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      _ruta,
      queryParameters: {
        if (texto.trim().isNotEmpty) 'q': texto.trim(),
        'archivados': archivados,
        'pagina': pagina,
        'tamano': tamanoPagina,
      },
    );
    return Pagina.fromJson(r.data!, Paciente.fromJson);
  });

  Future<Paciente> obtener(String id) => _llamar(() async {
    final r = await _dio.get<Map<String, dynamic>>('$_ruta/$id');
    return Paciente.fromJson(r.data!);
  });

  Future<Paciente> crear(DatosPaciente datos) => _llamar(() async {
    final r = await _dio.post<Map<String, dynamic>>(
      _ruta,
      data: datos.toJson(),
    );
    return Paciente.fromJson(r.data!);
  });

  Future<Paciente> actualizar(String id, DatosPaciente datos) =>
      _llamar(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '$_ruta/$id',
          data: datos.toJson(),
        );
        return Paciente.fromJson(r.data!);
      });

  Future<Paciente> archivar(String id) => _cambiarArchivo(id, 'archivar');

  Future<Paciente> desarchivar(String id) => _cambiarArchivo(id, 'desarchivar');

  Future<Paciente> _cambiarArchivo(String id, String accion) =>
      _llamar(() async {
        final r = await _dio.patch<Map<String, dynamic>>('$_ruta/$id/$accion');
        return Paciente.fromJson(r.data!);
      });

  Future<T> _llamar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final pacientesRepositoryProvider = Provider<PacientesRepository>(
  (ref) => PacientesRepository(ref.watch(dioProvider)),
);
