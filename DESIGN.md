---
name: GERENZ DENT · Consultorio claro
description: Sistema de diseño de la app Android del consultorio. Código fuente en mobile/lib/core/theme/tokens.dart.
colors:
  celeste-50: "#EFF9FD"
  celeste-100: "#DAF1FB"
  celeste-500: "#3BB5E8"
  celeste-700: "#106C93"
  celeste-800: "#0A5676"
  verde-50: "#EEF9F4"
  verde-500: "#22B573"
  verde-600: "#1B925D"
  verde-700: "#177D4F"
  verde-800: "#13633F"
  neutro-50: "#F7F9FB"
  neutro-100: "#EFF4F5"
  neutro-200: "#E0E8EB"
  neutro-500: "#657C86"
  neutro-600: "#506871"
  neutro-700: "#3D535C"
  neutro-900: "#19282E"
  rojo-50: "#FDECEC"
  rojo-700: "#A61F1F"
  ambar-50: "#FFF6E0"
  ambar-700: "#8F5A00"
  ambar-800: "#6E4500"
  blanco: "#FFFFFF"
typography:
  titular:
    fontFamily: "Montserrat"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.4px"
  titulo:
    fontFamily: "Montserrat"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.2
  subtitulo:
    fontFamily: "Roboto"
    fontSize: "18px"
    fontWeight: 600
  cuerpo:
    fontFamily: "Roboto"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.4
  etiqueta:
    fontFamily: "Roboto"
    fontSize: "14px"
    fontWeight: 700
rounded:
  control: "12px"
  tarjeta: "16px"
  hoja: "28px"
  pildora: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
  xxxl: "48px"
components:
  boton-principal:
    backgroundColor: "{colors.verde-700}"
    textColor: "{colors.blanco}"
    rounded: "{rounded.control}"
    height: "52px"
  boton-secundario:
    backgroundColor: "{colors.blanco}"
    textColor: "{colors.neutro-900}"
    rounded: "{rounded.control}"
    height: "52px"
  boton-terciario:
    textColor: "{colors.celeste-700}"
    height: "48px"
  tarjeta:
    backgroundColor: "{colors.blanco}"
    rounded: "{rounded.tarjeta}"
  chip-estado-recordado:
    backgroundColor: "{colors.celeste-50}"
    textColor: "{colors.celeste-800}"
    rounded: "{rounded.pildora}"
  chip-estado-exito:
    backgroundColor: "{colors.verde-50}"
    textColor: "{colors.verde-800}"
    rounded: "{rounded.pildora}"
  chip-estado-aviso:
    backgroundColor: "{colors.ambar-50}"
    textColor: "{colors.ambar-800}"
    rounded: "{rounded.pildora}"
  chip-estado-peligro:
    backgroundColor: "{colors.rojo-50}"
    textColor: "{colors.rojo-700}"
    rounded: "{rounded.pildora}"
  chip-estado-neutro:
    backgroundColor: "{colors.neutro-100}"
    textColor: "{colors.neutro-700}"
    rounded: "{rounded.pildora}"
---

# DESIGN.md · GERENZ DENT ("Consultorio claro")

Fuente de verdad en código: `mobile/lib/core/theme/tokens.dart` (primitivos → semánticos → `Tono`),
`app_theme.dart` (tema Material 3) y `mobile/lib/core/ui/componentes.dart`.

## Overview

App de operación para un solo usuario no técnico. Fondo blanco levemente teñido de celeste, superficies
blancas con borde fino, el celeste como estructura (cabeceras, pestaña activa, enlaces) y el verde **solo**
en la acción principal de cada vista. Montserrat en titulares; Roboto en todo lo demás. Logo "Cristal" (ícono de muela de vidrio y nombre en Sora) en `docs/branding/`.
Distribución 60 % neutros · 30 % celeste · 10 % verde.

## Colors

- **Marca:** celeste #3BB5E8, blanco, verde #22B573. Los puros no se usan para texto ni íconos sobre blanco
  (2.3:1 y 2.7:1); para eso, celeste-700/800 y verde-700/800.
- **Funcionales (aprobados):** rojo (error, alergia, "No vino") y ámbar (vencido, deuda pendiente).
- **Neutros** teñidos de celeste: fondo neutro-50, texto neutro-900 (15.2:1), secundario neutro-600 (5.9:1),
  borde decorativo neutro-200, borde de control neutro-500 (4.4:1).
- Todos los pares en uso cumplen WCAG 2.2 AA (tabla en el documento del sistema).

## Typography

Cinco tamaños: 28 (titular, Montserrat 700) · 22 (título, Montserrat 600) · 18 (subtítulo, Roboto 600) ·
16 (cuerpo, mínimo) · 14 (solo chips y etiquetas cortas). Todo en sp: sigue la letra del sistema; probado
al 200 %.

## Layout

Una columna, margen de pantalla 16, escala 4/8. Más espacio arriba de un título (24) que debajo (8).
Las filas con una acción a la derecha la pasan debajo cuando la letra del sistema es ≥ 150 %
(`letraGrande`). Montos, horas ("p. m.") y teléfonos nunca se parten.

## Elevation & Depth

Plano: blanco sobre neutro-50 más un borde de 1 px. Sombra solo en el botón flotante y en las hojas de
Material.

## Shapes

Controles 12 · tarjetas 16 · hojas y diálogos 28 · chips en píldora. Nunca una tarjeta dentro de otra.

## Components

- **Botón principal:** relleno verde-700, texto blanco 18/600, alto 52. Uno por vista; si hay varios
  controles, solo el más cercano lo lleva.
- **Secundario:** contorno neutro-500. **Terciario:** texto celeste-700.
- **Chip de estado:** ícono + texto sobre su tono; TalkBack lee "Estado: …". Mapa de estados en
  `estado_visual.dart`.
- **Aviso:** fondo del tono, ícono y texto 16 (alergias, errores con "Reintentar").
- **Hoja de opciones:** reemplaza al menú ⋮; cada opción con nombre, explicación e ícono.
- **Esqueleto:** carga con la forma del contenido; sin pulso si el sistema pide quitar animaciones.
- **Estado vacío:** ícono + qué pasa + qué hacer.

## Do's and Don'ts

- Do: usar `Tokens`, `Tono`, `Espacio`, `Radios` y `TipoTam`; nunca un hex o un tamaño suelto.
- Do: estado = ícono + texto + tono. Nunca solo color.
- Do: verbos en los botones ("Guardar paciente", "Agendar control").
- Don't: dos botones verdes en la misma vista.
- Don't: texto celeste-500 o verde-500 sobre blanco.
- Don't: esconder acciones en ⋮ cuando el doctor las necesita a diario.
