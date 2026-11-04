import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdatos;
import 'package:timezone/timezone.dart' as tz;

/// Un aviso a programar.
class AvisoPlanificado {
  const AvisoPlanificado({
    required this.id,
    required this.cuando,
    required this.texto,
  });

  final int id;
  final DateTime cuando;
  final String texto;
}

/// Decide qué avisos programar (HU-15). Función pura para poder probarla.
///
/// Se programan los próximos [dias] días a la [hora] elegida. El de hoy se
/// personaliza si ya se sabe cuántos recordatorios faltan enviar
/// ([pendientesHoy]); si son 0, ese día no se avisa. Los demás días llevan un
/// texto general, porque el aviso es local y no consulta al servidor
/// (ADR-004). Cada vez que se abre la app se vuelve a planificar.
List<AvisoPlanificado> planificarAvisos({
  required DateTime ahora,
  required TimeOfDay hora,
  int? pendientesHoy,
  int dias = 14,
}) {
  final avisos = <AvisoPlanificado>[];
  for (var d = 0; d < dias; d++) {
    final cuando = DateTime(
      ahora.year,
      ahora.month,
      ahora.day + d,
      hora.hour,
      hora.minute,
    );
    if (!cuando.isAfter(ahora)) continue;
    final esHoy = d == 0;
    if (esHoy && pendientesHoy == 0) continue;
    avisos.add(
      AvisoPlanificado(
        id: 100 + d,
        cuando: cuando,
        texto: esHoy && pendientesHoy != null
            ? 'Mañana tienes $pendientesHoy paciente${pendientesHoy == 1 ? '' : 's'} por recordar. Toca para enviar los mensajes.'
            : 'Revisa a quién recordarle su cita de mañana.',
      ),
    );
  }
  return avisos;
}

/// Aviso diario en el teléfono (HU-15, ADR-004).
abstract class ServicioAvisos {
  Future<void> inicializar();

  /// Pide permiso de notificaciones (Android 13+). Devuelve si quedó activo.
  Future<bool> pedirPermiso();

  Future<void> programar({required TimeOfDay hora, int? pendientesHoy});

  Future<void> cancelarTodos();
}

class ServicioAvisosLocal implements ServicioAvisos {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  static const _titulo = 'GERENZ DENT · Recordatorios';
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios_diarios',
      'Recordatorios diarios',
      channelDescription: 'Aviso para enviar los recordatorios de mañana',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> inicializar() async {
    if (_listo) return;
    tzdatos.initializeTimeZones();
    // La app es solo para el consultorio en Perú.
    tz.setLocalLocation(tz.getLocation('America/Lima'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_aviso'),
      ),
    );
    _listo = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> pedirPermiso() async {
    await inicializar();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> programar({required TimeOfDay hora, int? pendientesHoy}) async {
    await inicializar();
    await _plugin.cancelAll();
    // Se planifica con la hora "de pared" de Lima, sin importar la zona
    // configurada en el teléfono.
    final ahora = tz.TZDateTime.now(tz.local);
    final ahoraEnLima = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      ahora.hour,
      ahora.minute,
      ahora.second,
    );
    final exacto = await _android?.canScheduleExactNotifications() ?? false;
    for (final aviso in planificarAvisos(
      ahora: ahoraEnLima,
      hora: hora,
      pendientesHoy: pendientesHoy,
    )) {
      final c = aviso.cuando;
      await _plugin.zonedSchedule(
        id: aviso.id,
        title: _titulo,
        body: aviso.texto,
        scheduledDate: tz.TZDateTime(
          tz.local,
          c.year,
          c.month,
          c.day,
          c.hour,
          c.minute,
        ),
        notificationDetails: _detalles,
        // Exacto si el sistema lo permite (USE_EXACT_ALARM); si no, Android
        // puede retrasarlo hasta una hora.
        androidScheduleMode: exacto
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelarTodos() async {
    await inicializar();
    await _plugin.cancelAll();
  }
}

final servicioAvisosProvider = Provider<ServicioAvisos>(
  (ref) => ServicioAvisosLocal(),
);
