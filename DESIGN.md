---
name: GERENZ DENT (estado actual, v1.1.0)
description: Sistema visual tal como está implementado antes del rediseño. Referencia del "antes", no la meta.
colors:
  celeste: "#3BB5E8"
  celeste-claro: "#7FD6F5"
  celeste-fondo: "#EAF7FD"
  verde: "#22B573"
  verde-oscuro: "#1E9E62"
  verde-boton: "#17804F"
  texto: "#1B2B33"
  gris-texto: "#5E7A86"
  error: "#C62828"
  blanco: "#FFFFFF"
  borde-tarjeta-inicio: "#DCE7EC"
typography:
  headline:
    fontFamily: "Roboto"
    fontSize: "24px"
    fontWeight: 400
  title:
    fontFamily: "Roboto"
    fontSize: "16px"
    fontWeight: 500
  body-large:
    fontFamily: "Roboto"
    fontSize: "18px"
    fontWeight: 400
  body:
    fontFamily: "Roboto"
    fontSize: "16px"
    fontWeight: 400
  button:
    fontFamily: "Roboto"
    fontSize: "18px"
    fontWeight: 600
rounded:
  chip: "16px"
  card: "12px"
  card-inicio: "16px"
  button: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
components:
  button-primary:
    backgroundColor: "{colors.verde-boton}"
    textColor: "{colors.blanco}"
    rounded: "{rounded.button}"
    height: "52px"
  card-ficha:
    backgroundColor: "{colors.celeste-fondo}"
    rounded: "{rounded.card}"
  card-inicio:
    backgroundColor: "{colors.blanco}"
    rounded: "{rounded.card-inicio}"
---

# DESIGN.md — estado actual (antes del rediseño)

> Documenta lo que hay en `mobile/lib/core/theme/` y en las pantallas a la fecha (v1.1.0, 2026-11-04).
> Es la línea base del rediseño; la Fase 2 lo reemplazará por el sistema nuevo.

## Overview

Material 3 casi por defecto: `ColorScheme.fromSeed(celeste)` con `primary` forzado al verde oscuro de botón.
Sin escala tipográfica propia ni tokens de espaciado, radio o elevación; los valores se escriben a mano en cada
pantalla. Inicio (v1.1) usa tarjetas blancas con borde; la ficha y la cuenta usan tarjetas celeste pálido sin
borde. El resultado es limpio pero genérico, y cada pantalla habla un dialecto distinto.

## Colors

- **Verde botón #17804F**: `colorScheme.primary`; botones rellenos, texto de TextButton, selección del calendario.
- **Verde #22B573 / verde oscuro #1E9E62**: íconos de éxito, "Enviado", fecha del control, barra de avance.
- **Celeste #3BB5E8**: `secondary`; ícono de "Hoy vienen", estado "Recordado", contador.
- **Celeste fondo #EAF7FD**: fondo de `Card` por defecto (ficha, cuenta, datos) y de avatares.
- **Tonos M3 derivados de la semilla** (no de marca): botón tonal "Agendar control"/"Registrar pago" (celeste
  grisáceo), FAB, barra de navegación e indicador, fondo de hojas inferiores y diálogos.
- **Error #C62828**: errores, deudas (todas), alergias, "No vinieron", "Vencido", "No vino".
- Fuera de tokens: `#DCE7EC` (borde de tarjetas de Inicio) escrito dos veces a mano.

## Typography

Roboto del sistema. `bodyLarge` 18, `bodyMedium` 16, botones 18/600. El resto, valores por defecto de M3 y
~10 `fontSize` literales (16, 17, 18). Los títulos de sección ("Próximo control", "Historial", "Deuda") usan
`titleMedium` (16/500): se confunden con el cuerpo.

## Layout

Una columna, padding 16. Separaciones 4/8/12/16/20/24 sin escala definida. Barra inferior M3 con 4 destinos.
Formularios en hojas inferiores con scroll.

## Elevation & Depth

Plano: tarjetas con elevación 0; el FAB es lo único con sombra.

## Shapes

Botones en píldora (M3), tarjetas de 12 (defecto) o 16 (Inicio), chips de estado de 16, campos con borde
rectangular de 4.

## Components

- **Botón principal**: FilledButton verde, 52 dp de alto.
- **Botón secundario**: OutlinedButton (borde gris) o FilledButton.tonal (celeste grisáceo M3), sin regla.
- **Tarjeta de control**: tratamiento + chip de estado + menú ⋮, fecha grande en verde/rojo, botones Asistió ·
  No vino · Reprogramar.
- **Chip de estado**: texto del color del estado sobre tinte al 12 %, sin ícono.
- **Fila de paciente**: avatar con inicial, nombre 18, WhatsApp; chevron o ícono de alergia.
- **Estados**: `VistaCargando` (spinner), `VistaError` (ícono + Reintentar), `confirmar()` (AlertDialog),
  `mostrarMensaje()` (SnackBar sin "Deshacer").

## Do's and Don'ts

- Do: texto base ≥ 16 y botones ≥ 52 dp (ya se cumple).
- Don't: escribir colores o tamaños a mano en las pantallas (hoy ocurre).
- Don't: comunicar estados solo con color o con tintes de bajo contraste (hoy ocurre).
