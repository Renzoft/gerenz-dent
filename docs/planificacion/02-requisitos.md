# 02 · Requisitos

Prioridad MoSCoW: **M** = Must (MVP), **S** = Should (MVP si alcanza), **C** = Could (futuro).

## 1. Historias de usuario

### Épica A — Acceso

| ID | Historia | Prio |
|---|---|---|
| HU-01 | Como doctor quiero iniciar sesión una sola vez y que la app me recuerde, para no escribir mi contraseña cada día. | M |

**Criterios de aceptación HU-01**
- Login con correo y contraseña. La sesión se mantiene (refresh token) hasta 30 días o hasta cerrar sesión.
- 5 intentos fallidos seguidos bloquean el login 15 min.
- El token se guarda cifrado en el dispositivo (Android Keystore).

### Épica B — Pacientes

| ID | Historia | Prio |
|---|---|---|
| HU-02 | Como doctor quiero registrar un paciente con solo nombre y WhatsApp, para hacerlo rápido. | M |
| HU-03 | Como doctor quiero agregar edad, alergias y una nota de forma opcional. | M |
| HU-04 | Como doctor quiero buscar un paciente escribiendo parte de su nombre o número. | M |
| HU-05 | Como doctor quiero ver la ficha del paciente: datos, próximo control, historial, deuda. | M |
| HU-06 | Como doctor quiero editar o archivar un paciente. | M |
| HU-07 | Como doctor quiero importar un contacto desde la agenda del celular para no escribir el número. | S |

**Criterios de aceptación**
- Nombre: obligatorio, 2–80 caracteres.
- WhatsApp: obligatorio; se normaliza a formato E.164 (`+51` por defecto si escribe 9 dígitos que empiezan en 9).
- No se permiten dos pacientes activos con el mismo número (se muestra el existente).
- Alergias: si tiene, se muestran como **alerta roja** en la ficha y en el control del día.
- Checkbox "Autoriza recibir recordatorios por WhatsApp" (marcado por defecto, el doctor lo pregunta de palabra).
- Archivar ≠ borrar: el paciente se oculta pero se conserva su historial y deuda.

### Épica C — Tratamientos (catálogo)

| ID | Historia | Prio |
|---|---|---|
| HU-08 | Como doctor quiero ver la lista de tratamientos que realizo, para elegir uno al registrar un control. | M |
| HU-09 | Como doctor quiero que cada tratamiento sugiera la fecha del próximo control (p. ej. brackets → +30 días). | M |
| HU-10 | Como doctor quiero agregar/editar tratamientos y su precio referencial. | S |

**Criterios de aceptación**
- El catálogo inicial se carga con la lista del consultorio ([08-catalogo-tratamientos.md](08-catalogo-tratamientos.md)) mediante una migración de datos semilla.
- Cada tratamiento: nombre, tipo de precio (`FIJO`, `POR_PIEZA`, `INICIAL_MAS_MENSUAL`), precio base,
  precio mensual (solo cuota mensual), intervalo de control en días (opc.), activo.

### Épica D — Próximo control (cita)

| ID | Historia | Prio |
|---|---|---|
| HU-11 | Como doctor quiero registrar el próximo control eligiendo paciente, tratamiento y fecha; hora y nota son opcionales. | M |
| HU-12 | Como doctor, al marcar "asistió", quiero que la app me proponga el siguiente control con la fecha sugerida. | M |
| HU-13 | Como doctor quiero marcar un control como confirmado, asistió, no asistió o cancelado. | M |
| HU-14 | Como doctor quiero reprogramar un control cambiando solo la fecha. | M |

**Criterios de aceptación**
- Fecha: obligatoria, no anterior a hoy. Selector con atajos: **+1 semana, +15 días, +1 mes, +3 meses, +6 meses**.
- Hora: opcional. Si se deja vacía, el mensaje usa el horario de apertura del día
  ("a partir de las 6:00 p. m.").
- Nota: opcional, máx. 140 caracteres.
- Un paciente puede tener **un solo control pendiente por tratamiento** (evita duplicados).

### Épica E — Recordatorios (Opción C)

| ID | Historia | Prio |
|---|---|---|
| HU-15 | Como doctor quiero recibir cada día una notificación "Mañana tienes N pacientes por recordar". | M |
| HU-16 | Como doctor quiero tocar "Enviar" y que se abra WhatsApp con el mensaje ya escrito para ese paciente. | M |
| HU-17 | Como doctor quiero que la app marque el control como "recordado" después de enviarlo. | M |
| HU-18 | Como doctor quiero ver los controles **vencidos** (pasó la fecha y no vino) y enviarles un mensaje de seguimiento. | M |
| HU-19 | Como doctor quiero marcar "confirmó" cuando el paciente responda "SÍ" en WhatsApp. | M |
| HU-20 | Como doctor quiero configurar la hora de la notificación diaria (por defecto **5:30 p. m.**, antes de abrir el consultorio). | S |

**Criterios de aceptación**
- La notificación es **local** (programada en el teléfono) → funciona aunque el servidor esté dormido.
  Se programan los próximos 14 días a la hora elegida (hora de Lima, exacta). El de hoy dice cuántos faltan
  enviar; los demás llevan un texto general. Se reprograma cada vez que se abre la app.
- Si N = 0, no se muestra notificación.
- Al volver de WhatsApp, la app pregunta "¿Se envió?" → Sí marca `RECORDADO` con fecha/hora.
- Vencido = fecha < hoy y estado ∈ {PENDIENTE, RECORDADO, CONFIRMADO}. Se muestra con días de atraso.
- Pacientes sin consentimiento de WhatsApp no aparecen en la lista de envío (se muestran con un aviso).

**Plantillas de mensaje (implementadas en `PlantillaMensaje`, trato de "usted", firmadas por el doctor)**

Recordatorio (día anterior):
```
Hola {nombre de pila} 👋, le saluda el Dr. Marco Munayco del consultorio odontológico *GERENZ DENT*.
Le recordamos su cita de *{tratamiento}* para mañana *{día} {dd} de {mes}* {hora_texto}
Por favor responda *SÍ* para confirmar, o escríbame si necesita cambiar la fecha. ¡Le espero! 🦷
```

Seguimiento (vencido):
```
Hola {nombre de pila} 👋, le saluda el Dr. Marco Munayco de *GERENZ DENT*.
Aún tiene pendiente su control de *{tratamiento}*. Le espero de lunes a viernes desde las 6:00 p. m., los sábados desde las 4:00 p. m. y los domingos de 8:00 a. m. a 10:00 p. m.
Responda a este mensaje para indicarme qué día puede venir. 🦷
```

Como el mensaje sale del WhatsApp personal del doctor, se escribe en primera persona y con "le" (neutro).
"mañana" cambia a "hoy" o "el …" según la fecha del control.

`{hora_texto}` = "a las 7:30 p. m." si hay hora, o "a partir de las 6:00 p. m." (según el día) si no la hay.

### Épica F — Deudas y pagos

| ID | Historia | Prio |
|---|---|---|
| HU-21 | Como doctor quiero que el costo del tratamiento se calcule solo según el catálogo (fijo, por pieza o inicial + mensual) y poder ajustarlo. | M |
| HU-22 | Como doctor quiero registrar un pago (abono) con monto, fecha y medio (efectivo, Yape, Plin, transferencia). | M |
| HU-23 | Como doctor quiero ver cuánto me debe cada paciente y el total que me deben. | M |
| HU-24 | Como doctor quiero ver la deuda del paciente cuando lo atiendo o le envío el recordatorio. | S |
| HU-25 | Como doctor quiero anular un pago registrado por error (sin borrarlo). | M |

**Criterios de aceptación**
- Saldo = Σ cargos válidos − Σ pagos válidos. Nunca se guarda: se calcula.
- Los cargos se generan automáticamente (ver modelo de datos §2.1); el monto sugerido es editable y un cargo
  puede anularse (p. ej. el doctor no cobró la cuota de ese mes).
- Tratamientos `POR_PIEZA` piden el número de piezas (por defecto 1).
- Montos en soles (PEN), 2 decimales, > 0. Se usa `BigDecimal` / `NUMERIC(10,2)`, nunca `double`.
- Un pago no puede dejar el saldo negativo (se avisa si el monto supera el saldo).
- Anular deja el registro con estado `ANULADO` y motivo (trazabilidad).

## 2. Requisitos no funcionales (ISO/IEC 25010)

| ID | Característica | Requisito | Cómo se verifica |
|---|---|---|---|
| RNF-01 | Usabilidad | Botones ≥ 48 dp, texto base ≥ 16 sp, máx. 3 campos obligatorios por formulario | Revisión de UI + prueba con el doctor |
| RNF-02 | Usabilidad | Toda la app en español (es-PE), fechas "lun 10 nov", horas "7:30 p. m." | Pruebas de widget |
| RNF-03 | Eficiencia | Respuesta de la API < 500 ms en caliente; arranque en frío < 60 s con pantalla "Conectando…" | Medición en Render |
| RNF-04 | Fiabilidad | Si la API no responde, la app reintenta y muestra un mensaje claro (nunca pantalla en blanco) | Pruebas de integración |
| RNF-05 | Seguridad | HTTPS, BCrypt, JWT de corta duración + refresh token, CORS cerrado, sin datos personales en logs ni en URLs de la API | Revisión OWASP |
| RNF-06 | Seguridad | Backup semanal cifrado de la BD | Prueba de restauración |
| RNF-07 | Mantenibilidad | Cobertura de pruebas ≥ 80 % en la lógica de dominio del backend; análisis estático sin errores | CI (JaCoCo, `flutter analyze`) |
| RNF-08 | Portabilidad | Android 8.0 (API 26) o superior | Prueba en el celular del doctor |
| RNF-09 | Escalabilidad | Módulos por funcionalidad; nuevos canales de notificación sin tocar el dominio | Revisión de arquitectura |
| RNF-10 | Costo | S/ 0 mensuales | — |

## 3. Reglas de negocio

| ID | Regla |
|---|---|
| RN-01 | El recordatorio se genera para los controles cuya fecha es **mañana** (zona horaria `America/Lima`). |
| RN-02 | Un control `ASISTIO`, `NO_ASISTIO` o `CANCELADO` es final y no genera recordatorios. |
| RN-03 | Al marcar `ASISTIO`, se propone crear el siguiente control con `fecha = hoy + intervalo del tratamiento`. |
| RN-04 | La hora por defecto del texto depende del día: L–V 18:00, sáb 16:00, dom 08:00. |
| RN-05 | Los pacientes archivados no aparecen en recordatorios pero sí en deudas si tienen saldo. |
| RN-06 | En tratamientos `INICIAL_MAS_MENSUAL`, la cuota mensual se carga al marcar `ASISTIO`, no por mes calendario. |
| RN-07 | Si el tratamiento tiene `edad_maxima_control`, la fecha sugerida solo se propone cuando el paciente tiene edad registrada y es menor o igual a ese límite (flúor: 12 años). |
| RN-08 | Los precios del catálogo son fijos; el doctor puede aplicar un descuento editando el monto del cargo de ese paciente. |
