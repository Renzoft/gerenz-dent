# 07 · Plan de calidad, revisión y despliegue

## 1. Estrategia de pruebas

| Nivel | Backend | App | Ejemplos clave |
|---|---|---|---|
| Unitarias | JUnit + Mockito | flutter_test + mocktail | Transiciones de estado del control; cálculo de saldo; texto del mensaje según día/hora; normalización del número `987654321 → +51987654321` |
| Integración | MockMvc + Testcontainers (PostgreSQL real) | — | Login + JWT; consultas "mañana" y "vencidos" con zona `America/Lima`; migraciones Flyway |
| Widget | — | flutter_test | Formulario de nuevo paciente (validaciones); tarjeta de recordatorio |
| E2E | — | integration_test | Login → crear paciente → ver en "Mañana" → enviar |
| Arquitectura | ArchUnit | — | `domain` no depende de `infrastructure` |
| Aceptación (UAT) | — | — | El doctor usa la app 1 semana con pacientes reales; checklist de criterios de éxito |

Casos límite obligatorios: cambio de mes/año, domingo vs. lunes (hora por defecto), paciente sin consentimiento,
pago que supera el saldo, número con espacios/guiones, nombre con tildes y ñ, arranque en frío del servidor.

## 2. Revisión

- Cada cambio entra por **Pull Request** a `main`, con CI en verde.
- Revisión de código por iteración (correctitud, simplicidad, seguridad).
- Revisión de seguridad antes de la v1.0 (OWASP API Top 10: auth, autorización por recurso, validación, rate limit).
- Revisión de usabilidad con el doctor (observarlo usar la app sin ayudarlo).

## 3. Ramas y versionado

- `main` siempre desplegable. Ramas `feat/…`, `fix/…`. Commits con Conventional Commits.
- Versiones SemVer: `v0.x` durante el desarrollo, `v1.0.0` al cerrar la iteración 5.

## 4. CI/CD (GitHub Actions)

| Workflow | Disparador | Pasos |
|---|---|---|
| `backend-ci` | PR/push en `backend/**` | build, tests (Testcontainers), JaCoCo, Spotless |
| `mobile-ci` | PR/push en `mobile/**` | `flutter analyze`, `flutter test` |
| `deploy-backend` | push a `main` | Render despliega automáticamente desde el Dockerfile |
| `release-apk` | tag `v*` | `flutter build apk --release` firmado → GitHub Release |
| `warmup` | cron diario 17:15 (Lima) | `curl /actuator/health` |
| `backup-db` | cron semanal | `pg_dump` cifrado → artefacto privado |

## 5. Entornos

| Entorno | Backend | BD | App |
|---|---|---|---|
| Local | `./gradlew bootRun` | PostgreSQL en Docker | Emulador Android |
| Producción | Render (Docker, free) | Neon (free) | APK instalado en el celular del doctor |

Instalación en el celular del doctor: descargar el APK de la GitHub Release (repositorio privado o enlace directo)
y permitir "instalar apps desconocidas" una sola vez. Firma con un keystore propio guardado fuera del repo
(si se pierde, no se puede actualizar sin desinstalar).

## 6. Herramientas a instalar antes de la fase de código

Editor único: **VS Code**.

| Herramienta | Para qué | Nota |
|---|---|---|
| JDK 21 | Backend | Ya instalado (`C:\Program Files\Java\jdk-21.0.12`), conviven JDK 17 (primero en el PATH) y 23 (`JAVA_HOME`). Se resuelve con **Gradle toolchains** fijando Java 21 en el proyecto, sin tocar la configuración global. |
| Flutter SDK | App | Agregar `flutter\bin` al PATH y correr `flutter doctor`. |
| Android SDK | Compilar el APK | Flutter lo necesita aunque no uses Android Studio: instalar Android Studio solo para el SDK/emulador, o las *command-line tools*. Alternativa al emulador: el celular por USB con depuración activada. |
| Docker Desktop | PostgreSQL local y Testcontainers | |
| Extensiones de VS Code | — | Flutter, Dart, Extension Pack for Java, Spring Boot Extension Pack, Gradle for Java, Docker, GitLens |
| Git + GitHub | Repositorio **público** (lo crea el usuario) | Nunca subir `.env`, keystore ni datos reales |
| Render + Neon | Producción | Cuentas gratuitas |
