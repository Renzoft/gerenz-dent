# 06 · Backlog y roadmap

Trabajo en **iteraciones de 1 semana**. Cada iteración entrega algo que funciona de punta a punta
(backend + app + pruebas) y termina con una revisión.

| Iteración | Objetivo | Historias | Entregable |
|---|---|---|---|
| **0 · Cimientos** | Repositorio, proyectos base, CI, BD, deploy "hola mundo" | — | API `/health` en Render, APK vacía con tema y logo |
| **1 · Acceso y pacientes** | Login + CRUD de pacientes | HU-01…HU-06 | Registrar y buscar pacientes |
| **2 · Tratamientos y controles** | Catálogo + próximo control + estados | HU-08, HU-09, HU-11…HU-14 | Agendar y marcar asistencia |
| **3 · Recordatorios** | Notificación diaria + wa.me + vencidos | HU-15…HU-19 | **Primer uso real por el doctor** 🎯 |
| **4 · Deudas y pagos** | Planes, pagos, saldos | HU-21…HU-25 | Pestaña Deudas |
| **5 · Pulido y piloto** | Inicio completo, ajustes, importar contacto, UAT | HU-07, HU-10, HU-20, HU-24 | **v1.0** instalada |

> El MVP útil para el doctor llega en la **iteración 3**. Desde ahí, cada iteración se le entrega como
> una actualización del APK.

## Definition of Done (por historia)

- [ ] Criterios de aceptación cumplidos.
- [ ] Pruebas unitarias / de integración / de widget escritas y en verde en CI.
- [ ] Sin advertencias en `./gradlew check` ni en `flutter analyze`.
- [ ] Endpoint documentado en OpenAPI.
- [ ] Revisado (diff leído completo) y fusionado a `main` mediante PR.
- [ ] Probado en un Android real.

## Backlog futuro (post v1.0)

| Idea | Valor |
|---|---|
| WhatsApp Cloud API (envío 100 % automático) | Alto, si algún día hay presupuesto |
| Sesiones / avance de tratamiento | Medio |
| Estadísticas: inasistencias, ingresos del mes | Medio |
| Recordatorio de control preventivo cada 6 meses | Alto (trae pacientes de vuelta) |
| Exportar deudas a Excel/PDF | Bajo |
| Usuario asistente con permisos | Bajo |
