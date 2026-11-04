import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/almacen_sesion.dart';
import '../data/auth_repository.dart';
import '../data/perfil_repository.dart';
import '../domain/sesion.dart';

/// Estado de la sesión: `null` = no hay sesión (mostrar login).
///
/// Al abrir la app se restaura la sesión guardada sin llamar a la red: así
/// abre al instante aunque el servidor esté "dormido". Si el access token
/// venció, el interceptor lo renueva en la primera petición.
class AuthController extends AsyncNotifier<Usuario?> {
  @override
  Future<Usuario?> build() async {
    final sesion = await ref.read(almacenSesionProvider).leer();
    if (sesion != null) {
      // Se abre al instante con los datos guardados y, en segundo plano, se
      // traen los del servidor (p. ej. si cambió el nombre o la hora del aviso).
      unawaited(Future.microtask(_sincronizarConServidor));
    }
    return sesion?.usuario;
  }

  Future<void> _sincronizarConServidor() async {
    try {
      final actual = await ref.read(perfilRepositoryProvider).yo();
      if (state.value != null) await actualizarUsuario(actual);
    } catch (_) {
      // Sin conexión: se siguen usando los datos guardados.
    }
  }

  /// Lanza [ApiError] si las credenciales son incorrectas o no hay conexión.
  Future<void> login(String email, String password) async {
    final sesion = await ref
        .read(authRepositoryProvider)
        .login(email, password);
    await ref.read(almacenSesionProvider).guardar(sesion);
    state = AsyncData(sesion.usuario);
  }

  Future<void> logout() async {
    final almacen = ref.read(almacenSesionProvider);
    final sesion = await almacen.leer();
    await almacen.borrar();
    state = const AsyncData(null);
    if (sesion != null) {
      await ref.read(authRepositoryProvider).logout(sesion.refreshToken);
    }
  }

  /// Actualiza los datos del usuario guardados (p. ej. la hora del aviso).
  Future<void> actualizarUsuario(Usuario usuario) async {
    final almacen = ref.read(almacenSesionProvider);
    final sesion = await almacen.leer();
    if (sesion != null) {
      await almacen.guardar(
        Sesion(
          accessToken: sesion.accessToken,
          refreshToken: sesion.refreshToken,
          usuario: usuario,
        ),
      );
    }
    state = AsyncData(usuario);
  }

  /// Lo llama el interceptor cuando el refresh token ya no sirve.
  Future<void> sesionExpirada() async {
    await ref.read(almacenSesionProvider).borrar();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Usuario?>(
  AuthController.new,
  retry: (intento, error) => null,
);
