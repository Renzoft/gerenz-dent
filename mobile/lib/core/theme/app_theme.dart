import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema de la app. Prioriza legibilidad (RNF-01): texto base ≥ 16 sp y
/// botones de al menos 52 dp de alto.
abstract final class AppTheme {
  static final ThemeData claro = _construir();

  static ThemeData _construir() {
    final esquema =
        ColorScheme.fromSeed(
          seedColor: AppColors.celeste,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.verdeBoton,
          onPrimary: AppColors.blanco,
          secondary: AppColors.celeste,
          onSecondary: AppColors.texto,
          surface: AppColors.blanco,
          onSurface: AppColors.texto,
          error: AppColors.error,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.blanco,
    );

    const tamanoBoton = Size.fromHeight(52);
    const textoBoton = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blanco,
        foregroundColor: AppColors.texto,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: tamanoBoton,
          textStyle: textoBoton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tamanoBoton,
          textStyle: textoBoton,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.celesteFondo,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
    );
  }
}
