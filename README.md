<p align="center">
  <img src="docs/branding/logo-horizontal.png" alt="GERENZ DENT · Consultorio odontológico" width="420">
</p>

# GERENZ DENT

App Android del consultorio odontológico **GERENZ DENT**. Le recuerda al doctor a quién avisar cada
día, hace el seguimiento de los pacientes que no vinieron y lleva las cuentas de cada tratamiento,
para que ningún paciente se pierda. **Versión 1.5.2.**

[![backend-ci](https://github.com/Renzoft/gerenz-dent/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Renzoft/gerenz-dent/actions/workflows/backend-ci.yml)
[![mobile-ci](https://github.com/Renzoft/gerenz-dent/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/Renzoft/gerenz-dent/actions/workflows/mobile-ci.yml)

## Funcionalidades

### Inicio: lo del día, en una pantalla
- **Recordatorios de mañana**: lista de los citados para mañana y un botón para enviarles el
  recordatorio por WhatsApp, uno por uno. A los que ya confirmaron no se les envía.
- **Hoy vienen**: quiénes tienen control hoy.
- **No vinieron**: pacientes cuya fecha pasó, con **Escribirle** para invitarlos a volver y, cuando
  responden, **Poner fecha**.
- **Próximos días**: los citados de la semana.
- **Aviso diario** a las 4:30 p. m. (hora configurable): *"Mañana tienes 3 pacientes por recordar"*.

### Agenda
- Calendario del mes con la cantidad de controles de cada día.
- Al tocar un día se ven sus pacientes, el tratamiento, la hora y el estado: por recordar, recordado,
  confirmó, asistió, no vino.

### Pacientes
- Registro rápido con nombre y WhatsApp. Edad, alergias y nota son opcionales. También se pueden
  **importar desde los contactos** del teléfono.
- Búsqueda por nombre o número, y pacientes archivados aparte.
- **Ficha del paciente** con lo esencial arriba (WhatsApp, alergias resaltadas, próximo control y
  deuda) y tres pestañas: **Controles · Pagos · Datos**.

### Controles
- **Agendar control** con fecha sugerida según el tratamiento (por ejemplo, brackets: cada mes) o con
  atajos como "En 1 semana" o "En 1 mes".
- **Asistió**: registra la visita, cobra la cuota si corresponde (brackets), pregunta si pagó algo y
  propone el siguiente control.
- **No vino**: pregunta **"¿Cuándo vuelve?"**. Con fecha, agenda el siguiente control sin cobrar de
  nuevo; con **"Todavía no sabe"**, el paciente queda en "No vinieron" para escribirle.
- **Cambiar fecha**, **El paciente confirmó** y **Cancelar control** (con confirmación).

### Recordatorios por WhatsApp
- Mensajes listos, en "usted" y firmados por el doctor. Se envían desde **su propio WhatsApp** con un
  toque, sin costo de API.
- Recordatorio el día anterior a la cita y mensaje de seguimiento para los que no vinieron.
- Solo a pacientes que autorizaron recibir mensajes.

### Pagos y deudas
- Cada tratamiento tiene su cuenta: precio fijo, por pieza o inicial + cuota mensual.
- **Registrar pago** en efectivo, Yape, Plin o transferencia, con la opción de pagar **todo** de una vez.
- Descuentos, cobros extra y anulaciones con motivo: nada se borra, todo queda en el historial.
- Pestaña **Deudas**: cuánto le deben en total y a quién, de mayor a menor.

### Catálogo de tratamientos
- Precios, cuotas y cada cuántos días sugerir el próximo control, editables desde **Ajustes**.
- Ordenado de la A a la Z. Los tratamientos que ya no se hacen se desactivan sin perder su historial.

### Pensada para el doctor
- Letras y botones grandes, y alto contraste (WCAG 2.2 AA). Funciona con la letra del sistema al 200 %.
- Lenguaje del consultorio, una acción principal por pantalla y confirmación antes de lo irreversible.
- Si el servidor estaba en pausa, la app espera y carga sola, sin tener que cerrarla.

## Tecnología

| Capa | Tecnología |
|---|---|
| App móvil | Flutter 3.44 (Android) · Riverpod · go_router · dio |
| API | Java 21 · Spring Boot 4.1 · Spring Data JPA · Flyway |
| Base de datos | PostgreSQL 17 (Neon) |
| Infraestructura | Render (Docker) · GitHub Actions |
| Calidad | JUnit 5 · Testcontainers · ArchUnit · JaCoCo · Spotless · flutter_test · mocktail |

## Estructura

```
backend/   API Spring Boot (módulos por funcionalidad)
mobile/    App Flutter (features/ + core/)
docs/      Manual, planificación, ADR, despliegue, identidad visual
.github/   CI/CD
```

## Desarrollo local

Requisitos: JDK 21, Flutter 3.44, Android SDK, Docker Desktop.

```bash
docker compose up -d                       # PostgreSQL local (puerto 5433)
cd backend && ./gradlew bootRun            # API → http://localhost:8080/actuator/health
cd mobile && flutter run                   # App en el emulador (usa http://10.0.2.2:8080)
```

Pruebas: `./gradlew build` (backend, requiere Docker) · `flutter test` (mobile).
Formato: `./gradlew spotlessApply` · `dart format lib test`.

Producción: API en <https://gerenzdent-api.onrender.com> (Render + Neon). Ver [docs/despliegue.md](docs/despliegue.md).

## Documentación

- [Manual de uso](docs/manual-de-uso.md) (para el doctor)
- [Prueba de aceptación con el doctor](docs/prueba-con-el-doctor.md)
- [Publicar una versión](docs/publicar-version.md) · [Despliegue](docs/despliegue.md)
- [Sistema de diseño](DESIGN.md) · [Identidad visual](docs/branding/README.md)

### Planificación

1. [Visión y alcance](docs/planificacion/01-vision-y-alcance.md)
2. [Requisitos](docs/planificacion/02-requisitos.md)
3. [Modelo de datos](docs/planificacion/03-modelo-de-datos.md)
4. [Arquitectura y ADR](docs/planificacion/04-arquitectura.md)
5. [Backlog y roadmap](docs/planificacion/06-backlog-y-roadmap.md)
6. [Calidad y despliegue](docs/planificacion/07-calidad-y-despliegue.md)
7. [Catálogo de tratamientos](docs/planificacion/08-catalogo-tratamientos.md)

## Licencia

[MIT](LICENSE)
