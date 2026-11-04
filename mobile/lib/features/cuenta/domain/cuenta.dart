/// Cómo pagó el paciente.
enum MedioPago {
  efectivo('EFECTIVO', 'Efectivo'),
  yape('YAPE', 'Yape'),
  plin('PLIN', 'Plin'),
  transferencia('TRANSFERENCIA', 'Transferencia'),
  tarjeta('TARJETA', 'Tarjeta'),
  otro('OTRO', 'Otro');

  const MedioPago(this.api, this.etiqueta);

  final String api;
  final String etiqueta;

  static MedioPago desdeApi(String? v) =>
      values.firstWhere((m) => m.api == v, orElse: () => efectivo);
}

enum ConceptoCargo {
  inicial('INICIAL', 'Pago inicial'),
  mensual('MENSUAL', 'Cuota mensual'),
  tratamiento('TRATAMIENTO', 'Tratamiento'),
  otro('OTRO', 'Otro cargo');

  const ConceptoCargo(this.api, this.etiqueta);

  final String api;
  final String etiqueta;

  static ConceptoCargo desdeApi(String? v) =>
      values.firstWhere((c) => c.api == v, orElse: () => otro);
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

class Cargo {
  const Cargo({
    required this.id,
    required this.concepto,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.anulado = false,
    this.motivoAnulacion,
  });

  factory Cargo.fromJson(Map<String, dynamic> j) => Cargo(
    id: j['id'] as String,
    concepto: ConceptoCargo.desdeApi(j['concepto'] as String?),
    descripcion: j['descripcion'] as String?,
    monto: _num(j['monto']),
    fecha: DateTime.parse(j['fecha'] as String),
    anulado: j['estado'] == 'ANULADO',
    motivoAnulacion: j['motivoAnulacion'] as String?,
  );

  final String id;
  final ConceptoCargo concepto;
  final String? descripcion;
  final double monto;
  final DateTime fecha;
  final bool anulado;
  final String? motivoAnulacion;

  String get titulo => descripcion ?? concepto.etiqueta;
}

class Pago {
  const Pago({
    required this.id,
    required this.monto,
    required this.fecha,
    required this.medio,
    this.nota,
    this.anulado = false,
    this.motivoAnulacion,
  });

  factory Pago.fromJson(Map<String, dynamic> j) => Pago(
    id: j['id'] as String,
    monto: _num(j['monto']),
    fecha: DateTime.parse(j['fecha'] as String),
    medio: MedioPago.desdeApi(j['medio'] as String?),
    nota: j['nota'] as String?,
    anulado: j['estado'] == 'ANULADO',
    motivoAnulacion: j['motivoAnulacion'] as String?,
  );

  final String id;
  final double monto;
  final DateTime fecha;
  final MedioPago medio;
  final String? nota;
  final bool anulado;
  final String? motivoAnulacion;
}

/// Un tratamiento del paciente con sus movimientos y saldo.
class CuentaPlan {
  const CuentaPlan({
    required this.planId,
    required this.tratamientoId,
    required this.tratamientoNombre,
    required this.activo,
    required this.totalCargos,
    required this.totalPagos,
    required this.saldo,
    this.piezas,
    this.cargos = const [],
    this.pagos = const [],
  });

  factory CuentaPlan.fromJson(Map<String, dynamic> j) {
    final t = j['tratamiento'] as Map<String, dynamic>;
    return CuentaPlan(
      planId: j['planId'] as String,
      tratamientoId: t['id'] as String,
      tratamientoNombre: t['nombre'] as String,
      piezas: j['piezas'] as int?,
      activo: j['estado'] == 'ACTIVO',
      totalCargos: _num(j['totalCargos']),
      totalPagos: _num(j['totalPagos']),
      saldo: _num(j['saldo']),
      cargos: (j['cargos'] as List<dynamic>? ?? [])
          .map((e) => Cargo.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagos: (j['pagos'] as List<dynamic>? ?? [])
          .map((e) => Pago.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String planId;
  final String tratamientoId;
  final String tratamientoNombre;
  final int? piezas;
  final bool activo;
  final double totalCargos;
  final double totalPagos;
  final double saldo;
  final List<Cargo> cargos;
  final List<Pago> pagos;

  bool get debe => saldo > 0;
}

class CuentaPaciente {
  const CuentaPaciente({required this.deuda, required this.planes});

  factory CuentaPaciente.fromJson(Map<String, dynamic> j) => CuentaPaciente(
    deuda: _num(j['deuda']),
    planes: (j['planes'] as List<dynamic>)
        .map((e) => CuentaPlan.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final double deuda;
  final List<CuentaPlan> planes;

  /// Plan activo de ese tratamiento (si ya existe, al agendar no se crea otro).
  CuentaPlan? planActivoDe(String tratamientoId) => planes
      .where((p) => p.activo && p.tratamientoId == tratamientoId)
      .firstOrNull;
}

class DeudaPaciente {
  const DeudaPaciente({
    required this.pacienteId,
    required this.nombre,
    required this.whatsapp,
    required this.deuda,
    this.archivado = false,
  });

  factory DeudaPaciente.fromJson(Map<String, dynamic> j) => DeudaPaciente(
    pacienteId: j['pacienteId'] as String,
    nombre: j['nombre'] as String,
    whatsapp: j['whatsapp'] as String,
    archivado: j['archivado'] as bool? ?? false,
    deuda: _num(j['deuda']),
  );

  final String pacienteId;
  final String nombre;
  final String whatsapp;
  final bool archivado;
  final double deuda;
}

class ResumenDeudas {
  const ResumenDeudas({required this.total, required this.pacientes});

  factory ResumenDeudas.fromJson(Map<String, dynamic> j) => ResumenDeudas(
    total: _num(j['total']),
    pacientes: (j['pacientes'] as List<dynamic>)
        .map((e) => DeudaPaciente.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final double total;
  final List<DeudaPaciente> pacientes;
}
