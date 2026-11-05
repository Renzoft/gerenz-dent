# Identidad visual — GERENZ DENT (v2, "Cristal")

Elegida el 2026-11-05 entre 10 propuestas (dos rondas). Concepto: una **muela de vidrio** con reflejo y
un destello, sobre luces celeste y verde en un fondo celeste profundo. Conserva lo que funcionaba del
logo anterior (el diente que brilla) con un estilo de ícono actual.

## Archivos

| Archivo | Uso |
|---|---|
| `icono-app.svg` | Ícono completo (fuente vectorial) |
| `logo-horizontal.png` | Ícono + "GERENZ DENT" + "Consultorio odontológico" (copia de la app) |

En la app (`mobile/assets/branding/`):

| Archivo | Uso |
|---|---|
| `icono-app.png` | Ícono completo 1024 px (lo usa `flutter_launcher_icons`) |
| `icono-foreground.png` / `icono-fondo.png` | Capas del ícono adaptativo de Android (muela + luces) |
| `logo-horizontal.png` | Pantalla de inicio de sesión |
| `logo-marca.png` | Encabezado de Inicio (ícono + nombre, sin subtítulo) |
| `carga-centro.png` | Centro de la pantalla de carga (blanco, va sobre el fondo con luces) |

Los PNG se exportan a 4x desde HTML/SVG (el nombre usa la fuente Sora, que no va dentro de la app).
Para regenerar los íconos de Android: `cd mobile && dart run flutter_launcher_icons`.

## Nombre

**GERENZ DENT** son dos palabras, con un espacio un poco más amplio que el normal.
Letra: **Sora ExtraBold** (SIL OFL); subtítulo en Sora Medium con espaciado 0.32 em.
"GERENZ" en celeste-800 `#0A5676` y "DENT" en `#1C8FC6` (sobre fondo oscuro: blanco y `#3BB5E8`).

## Colores

| Uso | Hex |
|---|---|
| Fondo del ícono y de la pantalla de carga | `#0A5676` (celeste-800) |
| Luz celeste | `#3BB5E8` |
| Luz verde | `#22B573` |
| Muela y destello | blanco (relleno al 30 %, borde y reflejo al 100 %) |

Solo colores de la marca o tonos de ellos; ninguno nuevo.
