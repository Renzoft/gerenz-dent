/// Usuario autenticado (el doctor).
class Usuario {
  const Usuario({required this.id, required this.nombre, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    email: json['email'] as String,
  );

  final String id;
  final String nombre;
  final String email;

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'email': email};
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
