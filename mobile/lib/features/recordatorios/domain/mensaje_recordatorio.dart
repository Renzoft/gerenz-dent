import 'package:flutter/material.dart';

import '../../../core/formato/fechas.dart';
import '../../controles/domain/control.dart';

enum TipoRecordatorio {
  /// Antes de la cita (el día anterior).
  previo('PREVIO'),

  /// Después de la fecha, si el paciente no vino.
  seguimiento('SEGUIMIENTO');

  const TipoRecordatorio(this.api);

  final String api;

  static TipoRecordatorio desdeApi(String v) =>
      v == 'SEGUIMIENTO' ? seguimiento : previo;
}

/// Mensaje de WhatsApp ya armado por la API para un control.
class MensajeRecordatorio {
  const MensajeRecordatorio({
    required this.controlId,
    required this.tipo,
    required this.fecha,
    required this.estado,
    required this.tratamiento,
    required this.pacienteId,
    required this.pacienteNombre,
    required this.pacienteWhatsapp,
    required this.mensaje,
    this.hora,
    this.diasAtraso = 0,
    this.consienteWhatsapp = true,
    this.enlace,
    this.enviado = false,
    this.ultimoEnvio,
  });

  factory MensajeRecordatorio.fromJson(Map<String, dynamic> json) {
    final ultimo = json['ultimoEnvio'] as String?;
    return MensajeRecordatorio(
      controlId: json['controlId'] as String,
      tipo: TipoRecordatorio.desdeApi(json['tipo'] as String),
      fecha: DateTime.parse(json['fecha'] as String),
      hora: Fechas.horaDesdeApi(json['hora'] as String?),
      estado: EstadoControl.desdeApi(json['estado'] as String),
      diasAtraso: (json['diasAtraso'] as num?)?.toInt() ?? 0,
      tratamiento: json['tratamiento'] as String,
      pacienteId: json['pacienteId'] as String,
      pacienteNombre: json['pacienteNombre'] as String,
      pacienteWhatsapp: json['pacienteWhatsapp'] as String,
      consienteWhatsapp: json['consienteWhatsapp'] as bool? ?? true,
      mensaje: json['mensaje'] as String,
      enlace: json['enlace'] as String?,
      enviado: json['enviado'] as bool? ?? false,
      ultimoEnvio: ultimo == null ? null : DateTime.parse(ultimo).toLocal(),
    );
  }

  final String controlId;
  final TipoRecordatorio tipo;
  final DateTime fecha;
  final TimeOfDay? hora;
  final EstadoControl estado;
  final int diasAtraso;
  final String tratamiento;
  final String pacienteId;
  final String pacienteNombre;
  final String pacienteWhatsapp;
  final bool consienteWhatsapp;
  final String mensaje;

  /// Enlace wa.me. `null` si el paciente no autorizó recordatorios.
  final String? enlace;
  final bool enviado;
  final DateTime? ultimoEnvio;

  bool get sePuedeEnviar => enlace != null;

  /// Falta enviar y se puede enviar.
  bool get porEnviar => sePuedeEnviar && !enviado;
}
