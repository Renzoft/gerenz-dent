/// Configuración por entorno, inyectada al compilar:
///
/// `flutter run --dart-define=API_URL=https://mi-api.onrender.com`
///
/// Por defecto apunta a la API local vista desde el emulador de Android
/// (10.0.2.2 es el "localhost" de la PC dentro del emulador).
abstract final class Env {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}
