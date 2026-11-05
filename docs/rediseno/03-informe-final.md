# Rediseño de interfaz · Fases 3 y 4: Implementación y verificación

Fecha: 2026-11-05 · Rama: `rediseno/ui-fase-1` (14 commits sobre `main`, sin publicar)

Sistema aplicado a **toda la app**: [DESIGN.md](../../DESIGN.md) ·
detalle y contraste en [02-sistema-de-diseno.md](02-sistema-de-diseno.md) ·
diagnóstico de partida en [01-diagnostico.md](01-diagnostico.md).

## Verificación

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | Sin problemas |
| `flutter test` | **112 pruebas pasan** (92 originales + 4 de la ficha + 16 nuevas de datos extremos y accesibilidad) |
| break-ui: 6 pantallas × (320 dp con letra 100 % · 360 dp con letra 200 %) | 12/12 sin desbordes, después de corregir 7 fallas (abajo) |
| Guías de accesibilidad de Flutter (área táctil 48 dp Android, controles con etiqueta, contraste de texto) en Inicio, Pacientes, Ficha y Deudas | 4/4 cumplen |
| Contraste WCAG 2.2 AA de cada par de colores en uso | Todos ≥ 4.5:1 (texto) o ≥ 3:1 (gráficos); tabla en 02 |
| `flutter build apk --release` | Compila (59.7 MB; Montserrat suma unos 0.4 MB) |
| Emulador Pixel 5 (API 34), letra 100 % y 200 %, datos ficticios | Revisado pantalla por pantalla |
| Lógica, API, base de datos y rutas | Sin cambios: mismas llamadas, rutas y parámetros |

### break-ui: lo que se rompió con datos extremos y cómo se arregló

Datos ficticios con los límites reales del esquema: nombres de 80 caracteres, notas de 140,
alergias de 200, deudas de más de S/ 1 millón, 15 citados en un día, 1,284 pacientes y nombres de 2 letras.
Prueba de regresión: `mobile/test/rediseno/datos_extremos_test.dart`.

| # | Gravedad | Pantalla | Peor caso | Qué pasaba | Arreglo |
|---|---|---|---|---|---|
| 1 | Rota | Inicio | Letra al 200 % | "Enviar" / "Sin WhatsApp" no cabían junto al nombre (desborde de 64 px) | Con letra ≥ 150 % la acción baja debajo del nombre |
| 2 | Rota | Deudas | S/ 1,125,430.75 a 320 dp | El monto aplastaba el nombre a una letra por línea | En pantallas angostas o con letra grande, el monto va debajo |
| 3 | Rota | Ficha → Historial | Letra al 200 % | El chip "Cancelado" aplastaba el tratamiento | Con letra grande, el estado va debajo |
| 4 | Fea | Pacientes | 320 dp | "Archivados" + "1284 pacientes" se desbordaban | Se acomodan en dos líneas si no caben |
| 5 | Fea | Deudas, Inicio, Historial | Letra al 200 % | Las filas apiladas quedaban centradas | Las filas ocupan todo el ancho de la tarjeta |
| 6 | Fea | Pacientes, Ficha | Letra al 200 % | El teléfono se partía ("+51 966 555 / 444") | Siempre en una línea; si no cabe, se achica un poco |
| 7 | Fea | Toda la app | "7:30 p. m." | Se partía en "7:30 p." / "m." | Espacios que no se cortan en las horas |

**Lo que resistió desde el inicio:** nombres de 80 caracteres en la cabecera de la ficha (se leen completos),
alergia de 200 caracteres, nota de 140, 15 recordatorios, 39 deudores, plural de "1 paciente" y
"1 paciente con deuda", y un nombre de 2 letras (iniciales "J").

---

## Antes y después por pantalla

| Pantalla | Antes | Después | Principio |
|---|---|---|---|
| **Ficha del paciente** | Una columna larga; 3 botones grandes por control + ⋮; estados en texto claro (2.1–3.0:1) | Cabecera con lo esencial + pestañas Controles · Pagos · Datos; "Asistió" como única acción principal; "Otras opciones" explicadas; estados con ícono ≥ 6.7:1 | Agrupar; una acción principal; nada solo por color |
| **Inicio** | 4 tarjetas iguales con ícono, contadores de colores sin significado, error sin "Reintentar" | La tarea del día primero; búsqueda de pacientes a un toque; secciones livianas; esqueletos; "Reintentar" en cada sección | Lo más usado a la vista; cuatro estados |
| **Agendar control** | "+1 sem", "+15 d", "+3 m"; asteriscos; "Sin fecha elegida" en gris; errores al final | "En 1 semana", "En 1 mes"…; "¿Cuándo vuelve?"; fecha elegida en una caja; cada error junto a su campo | Lenguaje simple; errores que dicen cómo corregir |
| **Registrar pago** | "Monto pagado *", error en rojo al final | La deuda como chip arriba, "¿Cómo pagó?", error en el campo, botón con ícono | Formularios claros |
| **Pacientes** | Avatar con una letra, FAB "Paciente" celeste pálido, spinner | Iniciales, nombre a 18, alergia con ícono y etiqueta, **"Nuevo paciente"** en verde, esqueletos | Botones con verbo; jerarquía |
| **Nuevo / editar paciente** | "Nombre *", "WhatsApp *", "Guardar" | "Nombre completo", "WhatsApp" con ayuda, opcionales marcados, **"Guardar paciente"** | Etiquetas visibles; verbos |
| **Deudas** | Todo en rojo | Total en ámbar con chip "N pacientes con deuda"; lista en una tarjeta, de mayor a menor | Color con significado |
| **Ajustes** | Lista suelta; mostraba la URL del servidor | Agrupado (Recordatorios · Consultorio), "Cambiar", "Cerrar sesión" como botón; sin datos técnicos | Sin jerga |
| **Catálogo** | Texto gris suelto, "Tratamiento", "Guardar" | Aviso informativo, lista en tarjeta, "Agregar tratamiento", "Guardar tratamiento" | Consistencia |
| **Login y carga** | Fondo blanco, error en texto rojo | Fondo de marca, "Bienvenido", error como aviso, "Abriendo GERENZ DENT…" | Identidad |
| **Toda la app** | Tonos de Material ajenos a la marca, ~10 tamaños y colores escritos a mano, `AppColors` | Tema construido solo con tokens; `AppColors` eliminado; barra de navegación, diálogos, hojas y avisos con la marca; "Cancelar control" en rojo con "No, volver" | Consistencia; prevención de errores |

Capturas (todas con datos ficticios):
[ficha](capturas/despues/01-ficha-antes-despues.png) ·
[ficha al 200 %](capturas/despues/02-ficha-texto-200-antes-despues.png) ·
[Inicio](capturas/despues/06-inicio-antes-despues.png) ·
[Pacientes](capturas/despues/07-pacientes-antes-despues.png) ·
[Deudas](capturas/despues/08-deudas-antes-despues.png) ·
[Ajustes](capturas/despues/09-ajustes-antes-despues.png) ·
[Agendar](capturas/despues/10-agendar-antes-despues.png) ·
[Registrar pago y 200 %](capturas/despues/11-registrar-pago-y-texto-200.png) ·
[Otras opciones](capturas/despues/05-otras-opciones.png).

## Cambios que el doctor notará

- "No vino", "Cambiar fecha" (antes "Reprogramar"), "El paciente confirmó" y "Cancelar control" están en
  **Otras opciones**.
- La ficha tiene pestañas; los datos y "Archivar" están en **Datos**; los pagos, en **Pagos**.
- El manual de uso ([docs/manual-de-uso.md](../manual-de-uso.md)) ya está actualizado.

## Pendiente

| Tema | Por qué quedó fuera |
|---|---|
| **Deshacer** tras "Asistió" / "No vino" / "Cancelar" | La API no permite reabrir un control cerrado: requiere un cambio en el backend (fuera del alcance). Se mantiene la confirmación en lo destructivo. |
| Unir en una sola hoja las preguntas tras "Asistió" (¿pagó? → pago → ¿agendar?) | Cambia el flujo de interacción; conviene probarlo primero con el doctor. |
| Probar en el celular real del doctor | Todo se verificó en emulador; gestos, brillo y tamaño real se ven mejor en el equipo. |
| Subir la versión (p. ej. 1.2.0) y generar el APK firmado | Se hace al fusionar, como en versiones anteriores (docs/publicar-version.md). |
| Modo oscuro | Fuera de alcance por pedido. |
