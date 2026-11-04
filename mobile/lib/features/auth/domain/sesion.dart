import 'package:flutter/material.dart';

import '../../../core/formato/fechas.dart';

/// Usuario autenticado (el doctor).
class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.email,
    this.horaNotificacion = horaAvisoPorDefecto,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
    horaNotificacion:
        Fechas.horaDesdeApi(json['horaNotificacion'] as String?) ??
        horaAvisoPorDefecto,
  );

  /// 5:30 p. m.: antes de que abra el consultorio (L–V desde las 6 p. m.).
  static const horaAvisoPorDefecto = TimeOfDay(hour: 17, minute: 30);

  final String id;
  final String nombre;
  final String email;

  /// Hora del aviso diario de recordatorios (HU-20).
  final TimeOfDay horaNotificacion;

  Usuario conHora(TimeOfDay hora) =>
      Usuario(id: id, nombre: nombre, email: email, horaNotificacion: hora);

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'horaNotificacion': Fechas.horaAApi(horaNotificacion),
  };
}

/// Respuesta de login/refresh: par de tokens y usuario.
class Sesion {
  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  factory Sesion.fromJson(Map<String, dynamic> json) => Sesion(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
  );

  final String accessToken;
  final String refreshToken;
  final Usuario usuario;
}
