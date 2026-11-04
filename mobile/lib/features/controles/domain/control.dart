import 'package:flutter/material.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/theme/app_colors.dart';

/// Estado de un control (docs/planificacion/03-modelo-de-datos.md §3).
enum EstadoControl {
  pendiente('PENDIENTE', 'Pendiente', AppColors.grisTexto),
  recordado('RECORDADO', 'Recordado', AppColors.celeste),
  confirmado('CONFIRMADO', 'Confirmó', AppColors.verdeOscuro),
  asistio('ASISTIO', 'Asistió', AppColors.verde),
  noAsistio('NO_ASISTIO', 'No vino', AppColors.error),
  cancelado('CANCELADO', 'Cancelado', AppColors.grisTexto);

  const EstadoControl(this.api, this.etiqueta, this.color);

  final String api;
  final String etiqueta;
  final Color color;

  bool get esAbierto =>
      this == pendiente || this == recordado || this == confirmado;

  static EstadoControl desdeApi(String valor) =>
      values.firstWhere((e) => e.api == valor, orElse: () => pendiente);
}

/// Paciente resumido que viene con los controles de la agenda.
class PacienteDelControl {
  const PacienteDelControl({
    required this.id,
    required this.nombre,
    required this.whatsapp,
    this.consienteWhatsapp = true,
  });

  factory PacienteDelControl.fromJson(Map<String, dynamic> json) =>
      PacienteDelControl(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
        whatsapp: json['whatsapp'] as String,
        consienteWhatsapp: json['consienteWhatsapp'] as bool? ?? true,
      );

  final String id;
  final String nombre;
  final String whatsapp;
  final bool consienteWhatsapp;
}

/// Próximo control (cita aproximada) de un paciente.
class Control {
  const Control({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.estado,
    required this.tratamientoId,
    required this.tratamientoNombre,
    this.hora,
    this.nota,
    this.vencido = false,
    this.diasAtraso = 0,
    this.piezas,
    this.paciente,
    this.cerradoEn,
  });

  factory Control.fromJson(Map<String, dynamic> json) {
    final tratamiento = json['tratamiento'] as Map<String, dynamic>;
    final paciente = json['paciente'] as Map<String, dynamic>?;
    return Control(
      id: json['id'] as String,
      pacienteId: json['pacienteId'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      hora: Fechas.horaDesdeApi(json['hora'] as String?),
      nota: json['nota'] as String?,
      estado: EstadoControl.desdeApi(json['estado'] as String),
      cerradoEn: json['cerradoEn'] == null
          ? null
          : DateTime.parse(json['cerradoEn'] as String),
      vencido: json['vencido'] as bool? ?? false,
      diasAtraso: (json['diasAtraso'] as num?)?.toInt() ?? 0,
      tratamientoId: tratamiento['id'] as String,
      tratamientoNombre: tratamiento['nombre'] as String,
      piezas: json['piezas'] as int?,
      paciente: paciente == null ? null : PacienteDelControl.fromJson(paciente),
    );
  }

  final String id;
  final String pacienteId;
  final DateTime fecha;
  final TimeOfDay? hora;
  final String? nota;
  final EstadoControl estado;

  /// Día real en que se cerró (asistió, no vino o se canceló).
  final DateTime? cerradoEn;
  final bool vencido;
  final int diasAtraso;
  final String tratamientoId;
  final String tratamientoNombre;
  final int? piezas;

  /// Solo viene en la agenda y en vencidos.
  final PacienteDelControl? paciente;

  bool get esAbierto => estado.esAbierto;

  /// "Mañana · 7:30 p. m." o "mar 11 nov".
  String fechaTexto({DateTime? hoy}) {
    final dia = Fechas.relativa(fecha, hoy: hoy);
    return hora == null ? dia : '$dia · ${Fechas.hora(hora!)}';
  }
}

/// Datos para agendar un control nuevo.
class NuevoControl {
  const NuevoControl({
    required this.pacienteId,
    required this.tratamientoId,
    required this.fecha,
    this.hora,
    this.nota,
    this.piezas,
  });

  final String pacienteId;
  final String tratamientoId;
  final DateTime fecha;
  final TimeOfDay? hora;
  final String? nota;
  final int? piezas;

  Map<String, dynamic> toJson() => {
    'pacienteId': pacienteId,
    'tratamientoId': tratamientoId,
    'fecha': Fechas.aIso(fecha),
    if (hora != null) 'hora': Fechas.horaAApi(hora!),
    if (nota != null && nota!.trim().isNotEmpty) 'nota': nota!.trim(),
    'piezas': ?piezas,
  };
}

/// Resultado de cambiar el estado: al marcar "Asistió" puede venir la fecha
/// sugerida para el siguiente control.
class CambioDeEstado {
  const CambioDeEstado({required this.control, this.siguienteFechaSugerida});

  final Control control;
  final DateTime? siguienteFechaSugerida;
}
