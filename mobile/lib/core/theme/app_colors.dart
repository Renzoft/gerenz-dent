import 'package:flutter/painting.dart';

/// Paleta de marca (docs/branding/README.md).
abstract final class AppColors {
  static const blanco = Color(0xFFFFFFFF);
  static const celeste = Color(0xFF3BB5E8);
  static const celesteClaro = Color(0xFF7FD6F5);
  static const celesteFondo = Color(0xFFEAF7FD);
  static const verde = Color(0xFF22B573);
  static const verdeOscuro = Color(0xFF1E9E62);

  /// Verde para botones con texto blanco: contraste ≥ 4.5:1 (WCAG AA).
  static const verdeBoton = Color(0xFF17804F);
  static const grisTexto = Color(0xFF5E7A86);
  static const texto = Color(0xFF1B2B33);
  static const error = Color(0xFFC62828);
}
