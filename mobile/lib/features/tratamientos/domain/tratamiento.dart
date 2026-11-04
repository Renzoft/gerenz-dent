/// Cómo se cobra un tratamiento.
enum TipoPrecio {
  fijo('FIJO', 'Precio fijo'),
  porPieza('POR_PIEZA', 'Por pieza'),
  inicialMasMensual('INICIAL_MAS_MENSUAL', 'Inicial + mensual');

  const TipoPrecio(this.api, this.etiqueta);

  final String api;
  final String etiqueta;

  static TipoPrecio desdeApi(String valor) =>
      values.firstWhere((t) => t.api == valor, orElse: () => fijo);
}

/// Tratamiento del catálogo del consultorio.
class Tratamiento {
  const Tratamiento({
    required this.id,
    required this.nombre,
    required this.tipoPrecio,
    this.precioBase,
    this.precioMensual,
    this.intervaloControlDias,
    this.edadMaximaControl,
    this.activo = true,
  });

  factory Tratamiento.fromJson(Map<String, dynamic> json) => Tratamiento(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    tipoPrecio: TipoPrecio.desdeApi(json['tipoPrecio'] as String),
    precioBase: (json['precioBase'] as num?)?.toDouble(),
    precioMensual: (json['precioMensual'] as num?)?.toDouble(),
    intervaloControlDias: json['intervaloControlDias'] as int?,
    edadMaximaControl: json['edadMaximaControl'] as int?,
    activo: json['activo'] as bool? ?? true,
  );

  final String id;
  final String nombre;
  final TipoPrecio tipoPrecio;
  final double? precioBase;
  final double? precioMensual;
  final int? intervaloControlDias;
  final int? edadMaximaControl;
  final bool activo;

  bool get esPorPieza => tipoPrecio == TipoPrecio.porPieza;
}
