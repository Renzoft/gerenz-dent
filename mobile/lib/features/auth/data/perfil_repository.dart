import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/sesion.dart';

/// Datos actuales del doctor en el servidor (nombre, hora del aviso).
class PerfilRepository {
  PerfilRepository(this._dio);

  final Dio _dio;

  Future<Usuario> yo() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/api/v1/auth/yo');
      return Usuario.fromJson(r.data!);
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final perfilRepositoryProvider = Provider<PerfilRepository>(
  (ref) => PerfilRepository(ref.watch(dioProvider)),
);
