# 01 · Visión y alcance — GERENZ DENT App

## 1. Problema

El consultorio odontológico **GERENZ DENT** no lleva agenda. El doctor acuerda la siguiente visita de palabra
("vuelva en un mes") y el paciente suele olvidarla. Resultado: controles perdidos, tratamientos que se alargan
(p. ej. brackets) y deudas que no se siguen.

## 2. Visión

> Una app Android, de uso personal del doctor, que en **menos de 30 segundos por paciente** le permita registrar
> el próximo control y lo que le deben, y que **cada tarde le diga a quién recordarle su cita mañana**, dejando el
> mensaje de WhatsApp listo para enviar con un toque.

## 3. Usuarios

| Usuario | Descripción | Nivel técnico |
|---|---|---|
| Doctor (usuario principal) | Único usuario que registra datos. ~7+ pacientes por semana. | Básico — la UI debe ser grande, simple, con pocos campos |
| Hijo (soporte) | Instala, actualiza y da soporte. Usa la misma cuenta si necesita revisar algo. | Avanzado |
| Paciente (indirecto) | No usa la app. Solo recibe el WhatsApp. | — |

## 4. Contexto operativo

| Día | Horario de atención |
|---|---|
| Lunes a viernes | desde 18:00 |
| Sábado | desde 16:00 |
| Domingo | 08:00 – 22:00 |

- Hay internet (wifi y datos) en el consultorio → la app puede ser **online-first**.
- Las "citas" son **aproximadas**: el paciente puede venir el día indicado o días después. Lo importante es
  recordarle y **hacer seguimiento** si no vino.
- Los mensajes salen del **WhatsApp personal del doctor** (Opción C: semiautomático, ver ADR-001).

## 5. Alcance del MVP (v1.0)

| # | Funcionalidad | Incluido |
|---|---|---|
| 1 | Login (una cuenta) | ✅ |
| 2 | Pacientes: nombre, WhatsApp, edad (opc.), alergias (opc.), nota (opc.) | ✅ |
| 3 | Catálogo de tratamientos (lista del consultorio) | ✅ |
| 4 | Próximo control: paciente + tratamiento + fecha + hora (opc.) + nota breve (opc.) | ✅ |
| 5 | Recordatorio diario: notificación local + mensaje de WhatsApp prellenado (wa.me) | ✅ |
| 6 | Estados del control: pendiente → recordado → confirmado → asistió / no asistió / cancelado | ✅ |
| 7 | Seguimiento de controles vencidos (pasó la fecha y no vino) | ✅ |
| 8 | Deudas y pagos por tratamiento (costo total, abonos, saldo) | ✅ |
| 9 | Inicio: "Mañana", "Vencidos", "Deudas" | ✅ |

### Fuera de alcance (backlog futuro)

- Envío 100% automático (WhatsApp Cloud API) — la arquitectura ya lo contempla (`NotificationProvider`).
- Sesiones/avance de tratamientos (ortodoncia, endodoncia).
- Odontograma, fotos, radiografías.
- Estadísticas (inasistencias, ingresos mensuales).
- Varios usuarios / roles (asistente).
- Versión iOS.

## 6. Criterios de éxito

1. Registrar un paciente nuevo + su próximo control en **≤ 30 s**.
2. Enviar los recordatorios de mañana en **≤ 10 s por paciente**.
3. El doctor usa la app sin ayuda después de **una sesión de capacitación**.
4. Costo de operación: **S/ 0 al mes**.

## 7. Restricciones

- Presupuesto cero → servicios gratuitos (Render, Neon, GitHub Actions).
- Datos de salud = **datos sensibles** (Ley N.º 29733 y su reglamento): login obligatorio, HTTPS,
  contraseñas con hash, consentimiento del paciente para escribirle por WhatsApp, backups.
- Render (plan gratuito) "duerme" el servicio tras ~15 min sin tráfico → arranque en frío (ver ADR-003).
