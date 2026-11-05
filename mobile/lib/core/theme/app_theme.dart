import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'tokens.dart';

/// Temas de la app.
///
/// - [claro]: el tema de la v1.1 (se mantiene mientras dura el rediseño).
/// - [nuevo]: el sistema de diseño v2 (tokens.dart). En la Fase 3 reemplaza a
///   [claro] en toda la app; por ahora solo lo usa la pantalla piloto.
abstract final class AppTheme {
  static final ThemeData claro = _construirClaro();
  static final ThemeData nuevo = _construirNuevo();

  // -------------------------------------------------------------------------
  // v1.1 (sin cambios)
  // -------------------------------------------------------------------------

  static ThemeData _construirClaro() {
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

  // -------------------------------------------------------------------------
  // v2 (rediseño)
  // -------------------------------------------------------------------------

  static ThemeData _construirNuevo() {
    const esquema = ColorScheme(
      brightness: Brightness.light,
      primary: Tokens.accion,
      onPrimary: Tokens.textoSobreAccion,
      primaryContainer: Primitivos.verde100,
      onPrimaryContainer: Primitivos.verde900,
      secondary: Tokens.marcaFuerte,
      onSecondary: Primitivos.blanco,
      secondaryContainer: Primitivos.celeste100,
      onSecondaryContainer: Primitivos.celeste900,
      tertiary: Primitivos.celeste800,
      onTertiary: Primitivos.blanco,
      error: Tokens.error,
      onError: Primitivos.blanco,
      errorContainer: Primitivos.rojo50,
      onErrorContainer: Primitivos.rojo800,
      surface: Tokens.superficie,
      onSurface: Tokens.texto,
      onSurfaceVariant: Tokens.textoSecundario,
      surfaceContainerLowest: Tokens.superficie,
      surfaceContainerLow: Tokens.superficie,
      surfaceContainer: Tokens.fondo,
      surfaceContainerHigh: Tokens.superficie,
      surfaceContainerHighest: Primitivos.neutro100,
      outline: Tokens.bordeControl,
      outlineVariant: Tokens.borde,
      surfaceTint: Colors.transparent,
      inverseSurface: Primitivos.neutro900,
      onInverseSurface: Primitivos.blanco,
      inversePrimary: Primitivos.verde100,
    );

    const titulos = TextStyle(
      fontFamily: Fuentes.titulos,
      fontWeight: FontWeight.w600,
      color: Tokens.texto,
      height: 1.2,
    );
    const textos = TextTheme(
      headlineMedium: TextStyle(
        fontFamily: Fuentes.titulos,
        fontWeight: FontWeight.w700,
        fontSize: TipoTam.titular,
        letterSpacing: -0.4,
        color: Tokens.texto,
        height: 1.15,
      ),
      titleLarge: TextStyle(
        fontFamily: Fuentes.titulos,
        fontWeight: FontWeight.w600,
        fontSize: TipoTam.titulo,
        letterSpacing: -0.2,
        color: Tokens.texto,
        height: 1.2,
      ),
      titleMedium: TextStyle(
        fontSize: TipoTam.subtitulo,
        fontWeight: FontWeight.w600,
        color: Tokens.texto,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: TipoTam.cuerpo,
        fontWeight: FontWeight.w600,
        color: Tokens.texto,
        height: 1.3,
      ),
      bodyLarge: TextStyle(
        fontSize: TipoTam.subtitulo,
        color: Tokens.texto,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: TipoTam.cuerpo,
        color: Tokens.texto,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        fontSize: TipoTam.etiqueta,
        color: Tokens.textoSecundario,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: TipoTam.cuerpo,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontSize: TipoTam.etiqueta,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: TextStyle(
        fontSize: TipoTam.etiqueta,
        fontWeight: FontWeight.w500,
      ),
    );

    final formaControl = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radios.control),
    );
    const tamanoBoton = Size(48, 52);
    const textoBoton = TextStyle(
      fontSize: TipoTam.subtitulo,
      fontWeight: FontWeight.w600,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      textTheme: textos,
      scaffoldBackgroundColor: Tokens.fondo,
      dividerTheme: const DividerThemeData(
        color: Tokens.borde,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Tokens.fondo,
        foregroundColor: Tokens.texto,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: titulos.copyWith(fontSize: TipoTam.titulo),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: tamanoBoton,
          textStyle: textoBoton,
          shape: formaControl,
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: tamanoBoton,
          textStyle: textoBoton,
          shape: formaControl,
          foregroundColor: Tokens.texto,
          side: const BorderSide(color: Tokens.bordeControl),
          padding: const EdgeInsets.symmetric(horizontal: Espacio.xl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: Tokens.marcaFuerte,
          textStyle: const TextStyle(
            fontSize: TipoTam.cuerpo,
            fontWeight: FontWeight.w600,
          ),
          shape: formaControl,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      cardTheme: CardThemeData(
        color: Tokens.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.tarjeta),
          side: const BorderSide(color: Tokens.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Tokens.superficie,
        labelStyle: const TextStyle(color: Tokens.textoSecundario),
        floatingLabelStyle: const TextStyle(color: Tokens.marcaFuerte),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radios.control),
          borderSide: const BorderSide(color: Tokens.bordeControl),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radios.control),
          borderSide: const BorderSide(color: Tokens.bordeControl),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radios.control),
          borderSide: const BorderSide(color: Tokens.marcaFuerte, width: 2),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Tokens.marcaFuerte,
        unselectedLabelColor: Tokens.textoSecundario,
        indicatorColor: Tokens.marcaFuerte,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Tokens.borde,
        labelStyle: TextStyle(
          fontSize: TipoTam.cuerpo,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: TipoTam.cuerpo,
          fontWeight: FontWeight.w500,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Tokens.textoSecundario,
        titleTextStyle: TextStyle(
          fontSize: TipoTam.cuerpo,
          color: Tokens.texto,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: TipoTam.cuerpo,
          color: Tokens.textoSecundario,
        ),
        minVerticalPadding: Espacio.md,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Tokens.superficie,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: Primitivos.neutro300,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radios.hoja),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Tokens.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.hoja),
        ),
        titleTextStyle: titulos.copyWith(fontSize: TipoTam.titulo),
        contentTextStyle: const TextStyle(
          fontSize: TipoTam.cuerpo,
          color: Tokens.texto,
          height: 1.4,
        ),
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: Tokens.superficie,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: Tokens.superficieMarca,
        headerForegroundColor: Tokens.texto,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Primitivos.neutro900,
        contentTextStyle: const TextStyle(
          fontSize: TipoTam.cuerpo,
          color: Primitivos.blanco,
        ),
        actionTextColor: Primitivos.celeste200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.control),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Tokens.avance,
        linearTrackColor: Primitivos.neutro100,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Tokens.superficie,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(fontSize: TipoTam.cuerpo),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radios.control),
        ),
      ),
    );
  }
}
