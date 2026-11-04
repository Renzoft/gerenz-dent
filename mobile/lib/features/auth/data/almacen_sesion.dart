import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/sesion.dart';

/// Guarda la sesión en el almacenamiento cifrado del teléfono (Android Keystore).
abstract class AlmacenSesion {
  Future<Sesion?> leer();
  Future<void> guardar(Sesion sesion);
  Future<void> borrar();
}

class AlmacenSesionSeguro implements AlmacenSesion {
  AlmacenSesionSeguro([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  static const _claveAccess = 'access_token';
  static const _claveRefresh = 'refresh_token';
  static const _claveUsuario = 'usuario';

  final FlutterSecureStorage _almacen;

  @override
  Future<Sesion?> leer() async {
    final valores = await _almacen.readAll();
    final access = valores[_claveAccess];
    final refresh = valores[_claveRefresh];
    final usuario = valores[_claveUsuario];
    if (access == null || refresh == null || usuario == null) return null;
    return Sesion(
      accessToken: access,
      refreshToken: refresh,
      usuario: Usuario.fromJson(jsonDecode(usuario) as Map<String, dynamic>),
    );
  }

  @override
  Future<void> guardar(Sesion sesion) async {
    await _almacen.write(key: _claveAccess, value: sesion.accessToken);
    await _almacen.write(key: _claveRefresh, value: sesion.refreshToken);
    await _almacen.write(
      key: _claveUsuario,
      value: jsonEncode(sesion.usuario.toJson()),
    );
  }

  @override
  Future<void> borrar() => _almacen.deleteAll();
}

final almacenSesionProvider = Provider<AlmacenSesion>(
  (ref) => AlmacenSesionSeguro(),
);
