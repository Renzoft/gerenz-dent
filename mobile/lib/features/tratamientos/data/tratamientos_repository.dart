import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/tratamiento.dart';

class TratamientosRepository {
  TratamientosRepository(this._dio);

  final Dio _dio;

  Future<List<Tratamiento>> listar() async {
    try {
      final r = await _dio.get<List<dynamic>>('/api/v1/tratamientos');
      return r.data!
          .map((e) => Tratamiento.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final tratamientosRepositoryProvider = Provider<TratamientosRepository>(
  (ref) => TratamientosRepository(ref.watch(dioProvider)),
);

/// El catálogo casi no cambia: se carga una vez por sesión.
final catalogoProvider = FutureProvider<List<Tratamiento>>(
  (ref) => ref.watch(tratamientosRepositoryProvider).listar(),
  retry: (intento, error) => null,
);
