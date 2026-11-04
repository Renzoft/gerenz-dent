# Prueba de aceptación con el doctor (UAT)

Una semana de uso real con pacientes del consultorio. Objetivo: confirmar que la app resuelve el problema
(pacientes que olvidan su control) sin quitarle tiempo al doctor.

## Antes de empezar

- [ ] Instalar **GerenzDent-1.0.0.apk** en el celular del doctor (desinstalando antes la versión de pruebas, si la tuviera).
- [ ] Iniciar sesión con su cuenta (`ADMIN_EMAIL`).
- [ ] Aceptar el permiso de **notificaciones**; en Xiaomi/Huawei/Oppo, quitar el ahorro de batería a la app.
- [ ] Ajustes → **Probar aviso** → llega la notificación.
- [ ] Archivar los pacientes de prueba (y anular sus cargos si aparecen en Deudas).
- [ ] Revisar el **catálogo de tratamientos** con el doctor (precios vigentes) y confirmar la edad límite de limpieza (hoy 12 años).
- [ ] Borrar `ADMIN_PASSWORD` en Render (ya no se usa).
- [ ] Capacitación de 15 minutos usando [manual-de-uso.md](manual-de-uso.md).

## Durante la semana (observar sin ayudar)

| Tarea | Meta (01-vision-y-alcance §6) | Resultado |
|---|---|---|
| Registrar paciente + próximo control | ≤ 30 s | |
| Enviar los recordatorios de mañana | ≤ 10 s por paciente | |
| Usar la app sin ayuda | Tras 1 capacitación | |
| Costo de operación | S/ 0 al mes | |
| El aviso de las 5:30 p. m. llegó cada día | 7/7 | |

Anotar también:
- ¿Algún paciente respondió que no recibió el mensaje o que el texto no se entendía?
- ¿Qué pantalla o paso le pareció confuso?
- ¿Algo que haga a mano que la app debería hacer?

## Al terminar

- [ ] ¿Bajaron las inasistencias? (comparar con lo que el doctor recuerda de semanas anteriores)
- [ ] Ajustes pedidos por el doctor → issues en GitHub, priorizados para la versión 1.1.
- [ ] Decidir si se pasa al envío 100 % automático (WhatsApp Cloud API, ADR-001) según el costo y el valor percibido.
