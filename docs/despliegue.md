# Guía de despliegue (Render + Neon)

Costo: S/ 0. Se hace **una sola vez**; después cada merge a `main` con el CI en verde se despliega solo.

## Producción (desplegado el 2026-11-04)

| Recurso | Valor |
|---|---|
| API | <https://gerenzdent-api.onrender.com> · salud: [`/actuator/health`](https://gerenzdent-api.onrender.com/actuator/health) |
| Render | Blueprint `gerenz-dent` → servicio `gerenzdent-api` (Docker, Free, Virginia) |
| Neon | Proyecto `gerenz-dent` · rama `production` · BD `neondb` · AWS US East 1 · conexión con pooler |
| GitHub | Variable `API_URL` configurada → workflow `warmup` activo (17:15 Lima) |

Las credenciales viven solo en Neon y en las variables de entorno de Render.

## 1. Base de datos en Neon

1. Crear cuenta en <https://neon.tech> (puedes entrar con GitHub).
2. **New project** → nombre `gerenz-dent`, PostgreSQL **17**, región **AWS US East (N. Virginia)**, solo Postgres
   (sin Auth, Functions ni otros servicios; tampoco hace falta la CLI ni la skill de Neon).
3. Usar la base de datos por defecto `neondb`.
4. En **Connect**, activar **Connection pooling** y copiar los datos. Se arman así:

   | Variable | Valor |
   |---|---|
   | `DB_URL` | `jdbc:postgresql://<host-con-pooler>.neon.tech/neondb?sslmode=require` |
   | `DB_USER` | el usuario que muestra Neon |
   | `DB_PASSWORD` | la contraseña que muestra Neon |

   > Ojo: Neon muestra la URL como `postgresql://usuario:clave@host/db`. Para Java se separan usuario y
   > clave, y la URL empieza con `jdbc:postgresql://`.

No hace falta crear tablas: **Flyway** las crea al arrancar la API.

## 2. API en Render

1. Crear cuenta en <https://render.com> con GitHub y dar acceso al repositorio `Renzoft/gerenz-dent`.
2. **New → Blueprint** → elegir el repositorio. Render lee [`render.yaml`](../render.yaml).
3. Cuando pida los valores `DB_URL`, `DB_USER`, `DB_PASSWORD`, pegar los de Neon.
4. Esperar el primer despliegue (5–10 min la primera vez) y abrir
   `https://<tu-servicio>.onrender.com/actuator/health` → debe responder `{"status":"UP"}`.

## 3. Conectar el resto

| Dónde | Qué |
|---|---|
| GitHub → Settings → Secrets and variables → Actions → **Variables** | `API_URL` = `https://<tu-servicio>.onrender.com` (activa el workflow `warmup`) |
| App Flutter | `flutter run --dart-define=API_URL=https://<tu-servicio>.onrender.com` |

## 4. Desarrollo local

```bash
docker compose up -d                 # PostgreSQL 17 local en el puerto 5433
cd backend && ./gradlew bootRun      # API en http://localhost:8080 (Swagger: /swagger-ui.html)
cd mobile && flutter run             # el emulador llega a la API por http://10.0.2.2:8080
```

### Problema conocido en Windows: "Unable to establish loopback connection"

Java no logra crear su socket interno en la carpeta temporal del usuario. Solución (una vez, en PowerShell):

```powershell
New-Item -ItemType Directory -Force C:\tmp
[Environment]::SetEnvironmentVariable('JAVA_TOOL_OPTIONS', '-Djdk.net.unixdomain.tmpdir=C:\tmp', 'User')
```

Luego cerrar y abrir VS Code / la terminal.

## 5. El servidor "dormido" (plan gratuito)

Render apaga la API tras **15 minutos sin uso** y la enciende con la siguiente petición.

- **Arranque más rápido:** la imagen Docker trae una caché de clases de Java (CDS) que se entrena al
  construirla (ver `backend/Dockerfile`). Medido en local con 0.5 CPU y 512 MB: de ~78 s a ~30 s hasta
  "Started". En Render la espera total incluye además encender el contenedor.
- **La app no se traba mientras despierta:** las consultas (GET) se repiten solas hasta 100 s y, cuando
  el servidor responde, Inicio recarga lo que había fallado (`InterceptorDespertar`). No hace falta cerrar
  la app.
- **Cuotas:** Render da 750 h/mes por cuenta y Neon 100 CU-h/mes por proyecto. Con el uso de un solo doctor
  (unas 10 entradas al día) se usa una fracción de ambas. No conviene "despertar" la API cada pocos minutos
  para que nunca duerma: Render lo considera abuso del plan gratuito y la base de datos tampoco dormiría,
  así que se gastaría su cuota. Se mantiene solo el aviso diario de `warmup.yml` (4:15 p. m.).
