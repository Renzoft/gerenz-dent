# GERENZ DENT — App móvil (Flutter)

```bash
flutter pub get
flutter run                                              # API local (emulador → http://10.0.2.2:8080)
flutter run --dart-define=API_URL=https://<api>.onrender.com   # API en producción
flutter test
dart run flutter_launcher_icons                          # regenerar ícono desde assets/branding/
```

Estructura: `lib/core/` (tema, red, rutas, configuración) y `lib/features/<funcionalidad>/{data,domain,presentation}`.
