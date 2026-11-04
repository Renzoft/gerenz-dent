import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/sesion.dart';

/// Endpoints de autenticación. Usa el cliente HTTP **sin** interceptor de
/// sesión (si no, renovar el token se llamaría a sí mismo).
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<Sesion> login(String email, String password) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      return Sesion.fromJson(r.data!);
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  Future<Sesion> refrescar(String refreshToken) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      return Sesion.fromJson(r.data!);
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  /// Cierra la sesión en el servidor. Si no hay red, no importa: los tokens
  /// se borran del teléfono igual.
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {}
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioBaseProvider)),
);
