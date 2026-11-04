# GERENZ DENT

App Android para el consultorio odontológico **GERENZ DENT**: registro de pacientes, próximo control,
recordatorios por WhatsApp (semiautomáticos) y seguimiento de deudas.

[![backend-ci](https://github.com/Renzoft/gerenz-dent/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/Renzoft/gerenz-dent/actions/workflows/backend-ci.yml)
[![mobile-ci](https://github.com/Renzoft/gerenz-dent/actions/workflows/mobile-ci.yml/badge.svg)](https://github.com/Renzoft/gerenz-dent/actions/workflows/mobile-ci.yml)

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
docs/      Planificación, ADR, despliegue, identidad visual
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

Despliegue: ver [docs/despliegue.md](docs/despliegue.md).

## Documentación — Planificación

1. [Visión y alcance](docs/planificacion/01-vision-y-alcance.md)
2. [Requisitos](docs/planificacion/02-requisitos.md)
3. [Modelo de datos](docs/planificacion/03-modelo-de-datos.md)
4. [Arquitectura y ADR](docs/planificacion/04-arquitectura.md)
5. [Pantallas](docs/planificacion/05-pantallas.md)
6. [Backlog y roadmap](docs/planificacion/06-backlog-y-roadmap.md)
7. [Calidad y despliegue](docs/planificacion/07-calidad-y-despliegue.md)
8. [Catálogo de tratamientos](docs/planificacion/08-catalogo-tratamientos.md)
9. [Identidad visual](docs/branding/README.md)

## Licencia

[MIT](LICENSE)
