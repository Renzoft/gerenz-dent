import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/cuenta.dart';

/// Deudas y pagos. Todos los errores salen como [ApiError].
class CuentaRepository {
  CuentaRepository(this._dio);

  final Dio _dio;

  Future<CuentaPaciente> cuenta(String pacienteId) => _llamar(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/api/v1/pacientes/$pacienteId/cuenta',
    );
    return CuentaPaciente.fromJson(r.data!);
  });

  Future<ResumenDeudas> deudas() => _llamar(() async {
    final r = await _dio.get<Map<String, dynamic>>('/api/v1/deudas');
    return ResumenDeudas.fromJson(r.data!);
  });

  Future<CuentaPlan> registrarPago(
    String planId, {
    required double monto,
    required MedioPago medio,
    String? nota,
  }) => _plan(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/planes/$planId/pagos',
      data: {
        'monto': monto,
        'medio': medio.api,
        if (nota != null && nota.trim().isNotEmpty) 'nota': nota.trim(),
      },
    ),
  );

  Future<CuentaPlan> anularPago(String pagoId, String motivo) => _plan(
    () => _dio.patch<Map<String, dynamic>>(
      '/api/v1/pagos/$pagoId/anular',
      data: {'motivo': motivo},
    ),
  );

  Future<CuentaPlan> agregarCargo(
    String planId,
    String descripcion,
    double monto,
  ) => _plan(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/planes/$planId/cargos',
      data: {'descripcion': descripcion, 'monto': monto},
    ),
  );

  Future<CuentaPlan> ajustarCargo(String cargoId, double monto) => _plan(
    () => _dio.patch<Map<String, dynamic>>(
      '/api/v1/cargos/$cargoId',
      data: {'monto': monto},
    ),
  );

  Future<CuentaPlan> anularCargo(String cargoId, String motivo) => _plan(
    () => _dio.patch<Map<String, dynamic>>(
      '/api/v1/cargos/$cargoId/anular',
      data: {'motivo': motivo},
    ),
  );

  Future<CuentaPlan> _plan(
    Future<Response<Map<String, dynamic>>> Function() llamada,
  ) => _llamar(() async => CuentaPlan.fromJson((await llamada()).data!));

  Future<T> _llamar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

final cuentaRepositoryProvider = Provider<CuentaRepository>(
  (ref) => CuentaRepository(ref.watch(dioProvider)),
);
