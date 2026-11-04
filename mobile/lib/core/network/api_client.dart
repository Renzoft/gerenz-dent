import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/almacen_sesion.dart';
import '../../features/auth/data/auth_repository.dart';
import '../config/env.dart';
import 'interceptor_sesion.dart';

/// Los tiempos son generosos a propósito: en el plan gratuito de Render el
/// servidor "duerme" y puede tardar hasta ~1 minuto en despertar (ADR-003).
BaseOptions opcionesBase() => BaseOptions(
  baseUrl: Env.apiUrl,
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 75),
  headers: {'Accept': 'application/json'},
);

/// Cliente sin sesión: login, refresh, logout y health.
final dioBaseProvider = Provider<Dio>((ref) {
  final dio = Dio(opcionesBase());
  ref.onDispose(dio.close);
  return dio;
});

/// Cliente para el resto de la API: agrega el token y renueva la sesión.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(opcionesBase());
  dio.interceptors.add(
    InterceptorSesion(
      almacen: ref.watch(almacenSesionProvider),
      refrescar: (token) => ref.read(authRepositoryProvider).refrescar(token),
      // El reintento va por un cliente SIN este interceptor: si pasara por la
      // misma fila, un segundo 401 esperaría al primero y se bloquearía.
      reintentar: (opciones) => ref.read(dioBaseProvider).fetch(opciones),
      alExpirar: () =>
          ref.read(authControllerProvider.notifier).sesionExpirada(),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});
