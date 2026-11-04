# Publicar una versión de la app

## 🔐 La clave de firma (lo más importante)

Desde la **v1.0.0** el APK se firma con una clave propia de GERENZ DENT:

| Archivo | Dónde está | En git |
|---|---|---|
| `gerenzdent-release.jks` | `C:\Users\<usuario>\.gerenzdent\` | ❌ nunca |
| `key.properties` (contraseña y ruta) | misma carpeta + copia en `mobile/android/` | ❌ ignorado |

**Haz una copia de respaldo de la carpeta `.gerenzdent` en un lugar privado** (por ejemplo, Google Drive personal).
Android solo acepta actualizar la app si viene firmada con **la misma clave**: si se pierde, cada
actualización obligará a desinstalar la app del doctor.

> La versión 1.0.0 es la primera con esta clave: en los celulares que tenían una versión de pruebas
> (0.x, firmadas con la clave de debug) hay que **desinstalar una sola vez** e instalar la 1.0.0.
> Los datos no se pierden (están en el servidor); solo hay que iniciar sesión otra vez.

## Pasos para una versión nueva

1. Subir el número en `mobile/pubspec.yaml` (`version: 1.1.0+8`: nombre + número que siempre aumenta)
   y en la pantalla de Ajustes.
2. Fusionar el PR a `main` (Render despliega la API sola).
3. Esperar en Render → Events el **"Deploy live"**.
4. Compilar:

   ```bash
   cd mobile
   flutter build apk --release --dart-define=API_URL=https://gerenzdent-api.onrender.com
   ```

5. Verificar la firma (debe decir `CN=GERENZ DENT`):

   ```bash
   apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
   ```

6. Enviar el APK al celular e instalar **encima** de la versión anterior.

Si en otra PC no existe `mobile/android/key.properties`, el release se firma con la clave de debug y
**no** se podrá instalar encima: copiar antes la carpeta `.gerenzdent` y el `key.properties`.
