import 'package:flutter/animation.dart';

/// Sistema de diseño de GERENZ DENT ("Consultorio claro", ver DESIGN.md).
///
/// Tres capas, documentadas en DESIGN.md:
/// 1. [Primitivos]: escalas derivadas de los 3 colores de marca
///    (celeste #3BB5E8, blanco, verde #22B573) + 2 funcionales aprobados.
/// 2. [Tokens]: colores por propósito (texto, superficie, acción…).
/// 3. Tokens de componente: [Tono] y las clases de lib/core/ui/.
///
/// Las pantallas usan solo las capas 2 y 3, nunca un hex suelto.

// ---------------------------------------------------------------------------
// 1. Primitivos
// ---------------------------------------------------------------------------

abstract final class Primitivos {
  static const blanco = Color(0xFFFFFFFF);

  // Celeste de marca (500). Sus sombras 700+ sirven para texto e íconos.
  static const celeste50 = Color(0xFFEFF9FD);
  static const celeste100 = Color(0xFFDAF1FB);
  static const celeste200 = Color(0xFFB6E3F6);
  static const celeste500 = Color(0xFF3BB5E8);
  static const celeste600 = Color(0xFF1985B3);
  static const celeste700 = Color(0xFF106C93);
  static const celeste800 = Color(0xFF0A5676);
  static const celeste900 = Color(0xFF073E55);

  // Verde de marca (500). El 700 es el de los botones con texto blanco.
  static const verde50 = Color(0xFFEEF9F4);
  static const verde100 = Color(0xFFD9F2E7);
  static const verde500 = Color(0xFF22B573);
  static const verde600 = Color(0xFF1B925D);
  static const verde700 = Color(0xFF177D4F);
  static const verde800 = Color(0xFF13633F);
  static const verde900 = Color(0xFF0D452C);

  // Neutros teñidos con el matiz del celeste.
  static const neutro50 = Color(0xFFF7F9FB);
  static const neutro100 = Color(0xFFEFF4F5);
  static const neutro200 = Color(0xFFE0E8EB);
  static const neutro300 = Color(0xFFC5CFD3);
  static const neutro500 = Color(0xFF657C86);
  static const neutro600 = Color(0xFF506871);
  static const neutro700 = Color(0xFF3D535C);
  static const neutro800 = Color(0xFF283B43);
  static const neutro900 = Color(0xFF19282E);

  // Funcionales (no son de marca): solo para estados, con ícono y texto.
  static const rojo50 = Color(0xFFFDECEC);
  static const rojo100 = Color(0xFFF9D3D3);
  static const rojo700 = Color(0xFFA61F1F);
  static const rojo800 = Color(0xFF861818);
  static const ambar50 = Color(0xFFFFF6E0);
  static const ambar100 = Color(0xFFFDE9B8);
  static const ambar700 = Color(0xFF8F5A00);
  static const ambar800 = Color(0xFF6E4500);
}

// ---------------------------------------------------------------------------
// 2. Semánticos
// ---------------------------------------------------------------------------

abstract final class Tokens {
  // Fondos y superficies (60 %).
  static const fondo = Primitivos.neutro50;
  static const superficie = Primitivos.blanco;
  static const superficieHundida = Primitivos.neutro100;
  static const superficieMarca = Primitivos.celeste50;

  // Texto.
  static const texto = Primitivos.neutro900; // 15.2:1 sobre blanco
  static const textoSecundario = Primitivos.neutro600; // 5.9:1 sobre blanco
  static const textoMarca = Primitivos.celeste700; // 5.9:1 sobre blanco
  static const textoSobreAccion = Primitivos.blanco;

  // Bordes.
  static const borde = Primitivos.neutro200; // decorativo
  static const bordeControl = Primitivos.neutro500; // ≥ 3:1 (campos, botones)

  // Marca (30 %): estructura e identidad.
  static const marca = Primitivos.celeste500;
  static const marcaFuerte = Primitivos.celeste700;
  static const marcaSuave = Primitivos.celeste100;

  // Acción principal (10 %).
  static const accion = Primitivos.verde700; // blanco encima: 5.1:1
  static const accionSuave = Primitivos.verde50;
  static const avance = Primitivos.verde600; // 3.6:1 sobre neutro100

  // Error.
  static const error = Primitivos.rojo700;
  static const errorSuave = Primitivos.rojo50;
}

/// Tono de un estado: fondo, texto/ícono y borde. Todos los pares ≥ 4.5:1.
enum Tono {
  neutro(Primitivos.neutro100, Primitivos.neutro700),
  marca(Primitivos.celeste50, Primitivos.celeste800),
  exito(Primitivos.verde50, Primitivos.verde800),
  exitoFuerte(Primitivos.verde700, Primitivos.blanco),
  aviso(Primitivos.ambar50, Primitivos.ambar800),
  peligro(Primitivos.rojo50, Primitivos.rojo700);

  const Tono(this.fondo, this.contenido);

  final Color fondo;
  final Color contenido;
}

// ---------------------------------------------------------------------------
// Espaciado, radios, tipografía y movimiento
// ---------------------------------------------------------------------------

/// Escala de 4/8 dp.
abstract final class Espacio {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;

  /// Margen lateral de las pantallas.
  static const pantalla = lg;
}

abstract final class Radios {
  static const control = 12.0; // botones, campos
  static const tarjeta = 16.0;
  static const hoja = 28.0; // hojas inferiores (M3)
  static const pildora = 999.0; // chips de estado
}

/// Escala tipográfica corta: 5 tamaños (sp).
abstract final class TipoTam {
  static const titular = 28.0; // nombre del paciente, título de pantalla
  static const titulo = 22.0; // títulos de sección, fecha destacada
  static const subtitulo = 18.0; // tarjeta, cuerpo grande, botones
  static const cuerpo = 16.0; // texto base
  static const etiqueta = 14.0; // chips y etiquetas cortas (mínimo)
}

abstract final class Fuentes {
  /// Montserrat (la del logo) solo en titulares y títulos.
  static const titulos = 'Montserrat';
}

/// Movimiento con propósito: < 300 ms, ease-out al entrar.
abstract final class Movimiento {
  static const rapido = Duration(milliseconds: 120); // presionar
  static const normal = Duration(milliseconds: 200); // cambios de estado
  static const entrar = Duration(milliseconds: 250); // hojas, contenido nuevo
  static const curvaEntrar = Cubic(0.23, 1, 0.32, 1); // ease-out fuerte
  static const curvaMover = Cubic(0.77, 0, 0.175, 1); // ease-in-out
}
