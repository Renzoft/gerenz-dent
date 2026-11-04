/// Cómo se cobra un tratamiento.
enum TipoPrecio {
  fijo,
  porPieza,
  inicialMasMensual;

  static TipoPrecio desdeApi(String valor) => switch (valor) {
    'POR_PIEZA' => porPieza,
    'INICIAL_MAS_MENSUAL' => inicialMasMensual,
    _ => fijo,
  };
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
  });

  factory Tratamiento.fromJson(Map<String, dynamic> json) => Tratamiento(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    tipoPrecio: TipoPrecio.desdeApi(json['tipoPrecio'] as String),
    precioBase: (json['precioBase'] as num?)?.toDouble(),
    precioMensual: (json['precioMensual'] as num?)?.toDouble(),
    intervaloControlDias: json['intervaloControlDias'] as int?,
    edadMaximaControl: json['edadMaximaControl'] as int?,
  );

  final String id;
  final String nombre;
  final TipoPrecio tipoPrecio;
  final double? precioBase;
  final double? precioMensual;
  final int? intervaloControlDias;
  final int? edadMaximaControl;

  bool get esPorPieza => tipoPrecio == TipoPrecio.porPieza;
}
