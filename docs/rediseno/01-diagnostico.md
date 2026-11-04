# Rediseño de interfaz · Fase 1: Diagnóstico

Fecha: 2026-11-04 · Versión evaluada: 1.1.0 · Rama: `rediseno/ui-fase-1`

**Método:** revisión de diseño + auditoría técnica nativa (impeccable `critique` y `audit`). Como es una app
Android nativa (Flutter), no aplica el detector web. La app se ejecutó en el emulador (Pixel 5, API 34)
contra la API local con **datos ficticios**, también con el texto del sistema al 200 %. Capturas en
[`capturas/antes/`](capturas/antes/).

---

## (a) Mapa de pantallas y flujos

```
/cargando ─┬─> /login ──> Inicio
           └─────────────> Inicio
Barra inferior: Inicio · Pacientes · Deudas · Ajustes

Inicio (/)
 ├─ Recordatorios de mañana ─ Enviar / Enviar recordatorios (n) ─> WhatsApp ─> diálogo "¿Se envió…?"
 ├─ Hoy vienen ──────────────── fila ─> Ficha
 ├─ No vinieron ─────────────── Escribirle ─> WhatsApp ─> "¿Se envió…?"
 └─ Próximos días (plegado) ─── fila ─> Ficha

Pacientes (/pacientes) ── buscar · filtro Archivados · "Ver más"
 ├─ FAB "Paciente" ─> /pacientes/nuevo (formulario + elegir contacto) ─> Ficha ?agendar=1 ─> hoja Agendar
 └─ fila ─> Ficha

Ficha (/pacientes/:id)  [editar ─> /pacientes/:id/editar]
 ├─ Alergia (alerta)
 ├─ Próximo control: por cada control abierto ─ TarjetaControl
 │    ├─ Asistió ─> diálogo "¿Pagó algo hoy?" ─> hoja Registrar pago
 │    │            ─> diálogo "¿Agendar el siguiente control?" ─> hoja Agendar
 │    ├─ No vino · Reprogramar (calendario)
 │    └─ ⋮ El paciente confirmó · Cancelar control (confirmación)
 ├─ Agendar control ─> hoja Agendar (tratamiento, piezas, fecha rápida, hora, nota, costo, pagó hoy)
 ├─ Historial (controles cerrados)
 ├─ Deuda: por cada plan ─ Registrar pago (hoja) · › detalle del plan (hoja: cargos, pagos, anular, agregar cargo)
 ├─ Datos del paciente (plegado)
 └─ Archivar / Recuperar (confirmación)

Deudas (/deudas) ── total "Te deben" + lista ─> Ficha
Ajustes (/ajustes) ── hora del aviso (reloj) · Catálogo (/ajustes/catalogo ─> hoja editar tratamiento) · Cerrar sesión
```

Pantallas: 9 rutas, 4 hojas inferiores (Agendar, Registrar pago, Detalle del plan, Editar tratamiento) y
6 diálogos (¿Se envió?, ¿Pagó algo hoy?, ¿Agendar el siguiente?, Cancelar control, Archivar, Agregar cargo/anular).

---

## (b) Problemas priorizados

| # | Prioridad | Problema | Pantalla | Archivo |
|---|---|---|---|---|
| 1 | **P0** | Los estados no se leen: chips "Recordado" 2.12:1, "Asistió" 2.36:1, "Confirmó" 2.99:1; "Enviado" 3.43:1 a 16 sp. Fallan WCAG AA y además el estado va solo como texto coloreado, sin ícono. | Ficha, Inicio | `controles/domain/control.dart:8-13`, `tarjeta_control.dart:240-261`, `inicio_page.dart:361-381` |
| 2 | **P0** | En el historial el estado ("Asistió", "No vino") sale en letra diminuta (~11 sp) y un punto de color. Ilegible para el doctor. | Ficha | `tarjeta_control.dart:263-285` |
| 3 | **P1** | La ficha es una sola columna larga: cada control trae 3 botones grandes + menú, cada tratamiento con deuda trae otro botón grande "Registrar pago". Con 2 controles y 2 deudas hay **8 botones grandes** casi iguales. No hay una acción principal. | Ficha | `paciente_detalle_page.dart:131-228`, `tarjeta_control.dart:197-236`, `seccion_cuenta.dart:62-140` |
| 4 | **P1** | "Asistió" dispara una cadena de 2 diálogos y hasta 2 hojas (¿pagó? → pago → ¿agendar? → agendar). El doctor no ve el camino completo y no puede deshacer. | Ficha | `tarjeta_control.dart:37-108` |
| 5 | **P1** | Acciones escondidas: "El paciente confirmó" y "Cancelar control" solo están en el menú ⋮. | Ficha | `tarjeta_control.dart:169-184` |
| 6 | **P1** | Con letra del sistema al 200 % el nombre del tratamiento se corta a mitad de palabra ("Aplicació / n de flúor", "ortodonci / a)") porque comparte fila con el chip y el menú; la hora se parte ("7:30 p. / m."). | Ficha, Inicio | `tarjeta_control.dart:160-185`, `inicio_page.dart:312-358` |
| 7 | **P1** | Sin sistema visual: 3 tipos de tarjeta (blanca con borde en Inicio, celeste sin borde en la ficha, Card por defecto en Datos), 3 estilos de botón secundario (contorno, tonal celeste-gris de M3, TextButton), color `#DCE7EC` y ~10 tamaños de letra escritos a mano. El botón tonal y el FAB usan tonos de Material, no de la marca. | Todas | `core/theme/app_theme.dart`, `inicio_page.dart:195-199, 616-620` |
| 8 | **P1** | Hoja "Agendar control" larga y con jerga: atajos "+15 d", "+3 m", "+6 m", asteriscos "Tratamiento *", "Sin fecha elegida"; los campos de costo aparecen recién al elegir tratamiento (la hoja cambia de largo). | Agendar | `agendar_control_sheet.dart:235-481` |
| 9 | **P2** | Rojo para todo: deuda, alergia, "No vinieron", vencido, "No vino" y errores. En Deudas toda la lista es roja: nada destaca y transmite alarma. | Deudas, Ficha, Inicio | `deudas_page.dart`, `seccion_cuenta.dart:38-50` |
| 10 | **P2** | Estados de carga y error pobres: spinners en vez de esqueletos; en Inicio el error de una tarjeta es texto rojo sin "Reintentar"; la deuda de la ficha desaparece mientras carga y su error no tiene "Reintentar". | Inicio, Ficha | `inicio_page.dart:262-286`, `seccion_cuenta.dart:24-30`, `core/widgets/estados.dart` |
| 11 | **P2** | Sin "Deshacer": "No vino", "Asistió", "Archivar" y "Anular pago" muestran un SnackBar sin opción de revertir. | Ficha | `core/widgets/estados.dart:93-98` |
| 12 | **P2** | Jerarquía tipográfica plana: títulos de sección ("Próximo control", "Historial", "Deuda") a 16/500, iguales al cuerpo; el nombre del paciente no domina; la barra dice solo "Paciente". | Ficha | `paciente_detalle_page.dart:61, 131-136, 260, 286` |
| 13 | **P2** | Inicio: las 4 tarjetas pesan lo mismo; los contadores son píldoras de colores sin significado claro ni etiqueta para TalkBack (lee "1"); "Enviar"/"Escribirle" son botones de texto pequeños frente al botón grande. | Inicio | `inicio_page.dart:174-260, 392-466` |
| 14 | **P2** | TalkBack: solo 9 etiquetas/tooltips en toda la app; contadores, chips y avatar con inicial sin semántica; la alerta de alergia no se anuncia como alerta. | Todas | varias |
| 15 | **P3** | "Paciente" en el FAB no es un verbo y el FAB celeste pálido se pierde. | Pacientes | `pacientes_page.dart:55-59` |
| 16 | **P3** | Ajustes muestra la URL técnica del servidor ("http://10.0.2.2:8080"). | Ajustes | `ajustes_page.dart:130` |
| 17 | **P3** | Calendario con "Cancelar" y "ACEPTAR" (mayúsculas mezcladas); fondos grises M3 en hojas y diálogos que no son de la marca. | Hojas, diálogos | `app_theme.dart` |
| 18 | **P3** | Sin movimiento con propósito (0 animaciones): las tarjetas aparecen y desaparecen de golpe al cambiar de estado; no hay manejo de "reducir movimiento" (hoy no hace falta, sí cuando se agregue). | Todas | — |

### Puntaje

**Revisión de diseño (Nielsen, 0–4):** 24/40 — aceptable, con trabajo importante pendiente.

| # | Heurística | Nota | Hallazgo clave |
|---|---|---|---|
| 1 | Visibilidad del estado | 3 | Buen avance "Enviados 1 de 2"; los chips de estado no se leen |
| 2 | Lenguaje del usuario | 3 | Español claro; jerga en "+15 d", "plan", "cargo" |
| 3 | Control y libertad | 2 | Sin deshacer; cadena de diálogos tras "Asistió" |
| 4 | Consistencia | 2 | Tres tarjetas y tres botones secundarios distintos |
| 5 | Prevención de errores | 2 | "Asistió"/"No vino" sin confirmación ni deshacer |
| 6 | Reconocer antes que recordar | 2 | Acciones en ⋮, datos plegados |
| 7 | Flexibilidad y eficiencia | 3 | Envío en lote, atajos de fecha |
| 8 | Estética y minimalismo | 2 | Ficha saturada de botones iguales |
| 9 | Recuperación de errores | 2 | Errores de tarjeta sin "Reintentar" |
| 10 | Ayuda | 3 | Explicaciones breves en Inicio |

**Carga cognitiva (ficha):** falla 4 de 8 (foco único, jerarquía, ≤ 4 opciones, divulgación progresiva) → alta.

**Auditoría técnica (0–4):** 12/20 — aceptable.

| Dimensión | Nota | Hallazgo |
|---|---|---|
| Accesibilidad | 2 | Contraste de estados, semántica escasa, corte a 200 % |
| Rendimiento | 3 | Listas pequeñas; Pacientes ya pagina |
| Tema y apariencia | 2 | Tokens mínimos, valores a mano, tonos M3 ajenos a la marca |
| Convenciones Android | 3 | M3, NavigationBar, atrás y zonas seguras correctos |
| Adaptabilidad | 2 | Se rompe con letra grande; teclado sí se respeta en hojas |

### Lo que funciona (conservar)

- Inicio ordenado por la tarea del día, con explicación corta en cada tarjeta y un botón grande para enviar.
- Texto base de 16–18 sp y botones de 52 dp: buena base de legibilidad.
- Confirmación antes de cancelar y archivar; "Reintentar" en la conexión inicial; mensaje claro del arranque en frío.
- La alerta de alergia arriba de la ficha.

---

## (c) Causa probable de la confusión

1. **Todo pesa lo mismo.** En la ficha, Asistió, No vino, Reprogramar, Agendar control y Registrar pago son
   botones grandes casi iguales y se repiten por cada tratamiento. El doctor no sabe dónde mirar primero.
2. **Tres temas mezclados en una lista.** Agenda (controles), dinero (planes y pagos) y datos del paciente
   están apilados en una sola columna y repetidos por tratamiento; hay que bajar y recordar lo de arriba.
3. **Los estados no se ven.** "Recordado", "Confirmó" o "Asistió" están en colores claros y letra chica, sin
   ícono: el doctor no distingue de un vistazo en qué está cada cita.
4. **Pasos ocultos.** Tras "Asistió" aparecen preguntas en cadena, y algunas acciones viven en el menú ⋮.
5. **Cada pantalla es distinta.** Lo que aprende en Inicio (tarjetas blancas, contadores) no se repite en la
   ficha (tarjetas celestes, chips), así que no se vuelve familiar.

---

## (d) Contraste de la paleta tal como se usa hoy

| Combinación (texto / fondo) | Ratio | WCAG AA | Dónde |
|---|---|---|---|
| Texto #1B2B33 / blanco | 14.58:1 | Cumple | Todo el texto principal |
| Texto / celeste fondo #EAF7FD | 13.35:1 | Cumple | Tarjetas de la ficha |
| Gris #5E7A86 / blanco | 4.56:1 | Cumple (justo) | Textos secundarios |
| Gris / celeste fondo | 4.17:1 | Falla texto normal | Secundarios dentro de tarjetas de la ficha |
| Blanco / verde botón #17804F | 4.96:1 | Cumple | Botones principales |
| Verde botón / blanco | 4.96:1 | Cumple | "Enviar", "Escribirle" |
| Blanco / verde marca #22B573 | **2.65:1** | Falla | (no usar texto blanco sobre el verde de marca) |
| Verde #22B573 / blanco | **2.65:1** | Falla (incluso ícono < 3:1) | Íconos de éxito, barra de avance |
| Verde oscuro #1E9E62 / blanco | 3.43:1 | Solo texto grande | "Enviado" (16 sp: falla) |
| Verde oscuro / celeste fondo | 3.14:1 | Solo texto grande | Fecha del control (22 sp: cumple) |
| Celeste #3BB5E8 / blanco | **2.34:1** | Falla | Ícono "Hoy vienen", estado "Recordado" |
| Blanco / celeste | **2.34:1** | Falla | Contador de "Hoy vienen" |
| Texto / celeste | 6.22:1 | Cumple | (opción válida para texto sobre celeste) |
| Error #C62828 / blanco | 5.62:1 | Cumple | Errores, deudas |
| Error / tinte 8 % | 4.96:1 | Cumple | Alerta de alergia |
| Error / tinte 12 % | 4.64:1 | Cumple | Chips "Vencido", "No vino" |
| Verde / tinte 12 % | **2.36:1** | Falla | Chip "Asistió" |
| Verde oscuro / tinte 12 % | **2.99:1** | Falla | Chip "Confirmó" |
| Celeste / tinte 12 % | **2.12:1** | Falla | Chip "Recordado" |
| Gris / tinte 12 % | 3.95:1 | Falla texto normal | Chips "Pendiente", "Cancelado" |
| Verde / celeste fondo | **2.43:1** | Falla (< 3:1 gráfico) | Barra de avance de recordatorios |
| Borde #DCE7EC / blanco | 1.26:1 | Decorativo (no es control) | Borde de tarjetas de Inicio |

Conclusión: **el celeste y el verde de marca no sirven para texto ni íconos sobre blanco.** Para texto se
necesitan sus sombras (≈ celeste 700 y verde 700/800); los colores puros quedan para superficies grandes,
rellenos con texto oscuro y la identidad.

### Decisión pendiente para la Fase 2

La paleta de 3 colores no alcanza para los 7 estados (Pendiente, Recordado, Confirmó, Asistió, No vino,
Cancelado, Vencido) ni para "pagado / debe / anulado". Hoy ya se usa un rojo funcional (#C62828) que no es
de marca. En la Fase 2 propondré mantener **un rojo funcional** (errores, alergia, vencido) y, si hace falta,
**un ámbar funcional** (pendiente de pago / por recordar), siempre con ícono y texto. Requiere tu aprobación.
