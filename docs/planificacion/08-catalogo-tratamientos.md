# 08 · Catálogo de tratamientos (datos semilla)

Fuente: Dr. Marco Munayco (2026-11-03). Precios referenciales en **soles (S/)**; el doctor puede ajustar
el monto en cada caso (descuentos, casos especiales).

## Tipos de precio

Los precios del consultorio siguen tres formas distintas, así que el catálogo las modela explícitamente:

| Tipo | Significado | Cómo se genera la deuda |
|---|---|---|
| `FIJO` | Un precio por tratamiento | 1 cargo = precio |
| `POR_PIEZA` | Precio por diente | 1 cargo = precio × n.º de piezas (el doctor indica las piezas) |
| `INICIAL_MAS_MENSUAL` | Pago inicial + cuota mensual | 1 cargo inicial al empezar + 1 cargo mensual cada vez que el paciente **asiste** a un control |

## Catálogo inicial

| # | Tratamiento | Tipo | Precio base | Mensual | Intervalo de control sugerido |
|---|---|---|---|---|---|
| 1 | Blanqueamiento dental | FIJO | 200 | — | — |
| 2 | Brackets (ortodoncia) | INICIAL_MAS_MENSUAL | 500 | 100 | 30 días |
| 3 | Prótesis dental completa (juego) | FIJO | 1 000 | — | — |
| 4 | Prótesis dental parcial acrílica | FIJO | 400 | — | — |
| 5 | Prótesis dental parcial metálica | FIJO | 800 | — | — |
| 6 | Puente fijo de Ivocron | POR_PIEZA | 150 | — | — |
| 7 | Puente de porcelana | POR_PIEZA | 400 | — | — |
| 8 | Puente de disilicato de litio | POR_PIEZA | 500 | — | — |
| 9 | Puente de zirconio | POR_PIEZA | 700 | — | — |
| 10 | Limpieza dental y profilaxis | FIJO | 80 | — | 180 días (hasta 12 años*) |
| 11 | Extracción dental | FIJO | 70 | — | — |
| 12 | Carillas dentales de disilicato de litio | POR_PIEZA | 600 | — | — |
| 13 | Aplicación de flúor | FIJO | 50 | — | 180 días (hasta 12 años) |
| 14 | Carillas directas de resina | POR_PIEZA | 200 | — | — |

## Reglas validadas con el doctor (2026-11-03)

- **Precios fijos con descuentos ocasionales**: el monto sugerido de cada cargo es editable por paciente.
- **Brackets**: la cuota de S/ 100 se cobra cuando el paciente **asiste** al control, no por mes calendario.
- **Limpieza y flúor**: el control semestral aplica **solo a niños**. Cada tratamiento tiene el campo
  `edad_maxima_control` (años, inclusive); la fecha a +180 días se sugiere solo si el paciente tiene edad
  registrada y `edad ≤ edad_maxima_control`. En otros casos (o sin edad) no se sugiere fecha.
  - Flúor: **hasta los 12 años** (periodo de erupción de los dientes), según el doctor.
- "Intervalo sugerido" solo preselecciona la fecha; el doctor siempre puede cambiarla. En prótesis, puentes
  y carillas el número de sesiones varía, por eso no tienen intervalo fijo.

\* **Supuesto pendiente:** para limpieza se usa también 12 años mientras el doctor no indique otro límite
(es un dato del catálogo, se cambia sin tocar código).
