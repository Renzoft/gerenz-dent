/// Paciente tal como lo devuelve la API.
class Paciente {
  const Paciente({
    required this.id,
    required this.nombre,
    required this.whatsapp,
    this.edad,
    this.alergias,
    this.nota,
    this.consienteWhatsapp = true,
    this.archivado = false,
  });

  factory Paciente.fromJson(Map<String, dynamic> json) => Paciente(
    id: json['id'] as String,
    nombre: json['nombre'] as String,
    whatsapp: json['whatsapp'] as String,
    edad: json['edad'] as int?,
    alergias: json['alergias'] as String?,
    nota: json['nota'] as String?,
    consienteWhatsapp: json['consienteWhatsapp'] as bool? ?? true,
    archivado: json['archivado'] as bool? ?? false,
  );

  final String id;
  final String nombre;

  /// Formato E.164 (+51987654321).
  final String whatsapp;
  final int? edad;
  final String? alergias;
  final String? nota;
  final bool consienteWhatsapp;
  final bool archivado;

  bool get tieneAlergias => alergias != null && alergias!.isNotEmpty;

  DatosPaciente get datos => DatosPaciente(
    nombre: nombre,
    whatsapp: whatsapp,
    edad: edad,
    alergias: alergias,
    nota: nota,
    consienteWhatsapp: consienteWhatsapp,
  );
}

/// Datos que el doctor ingresa en el formulario (crear o editar).
class DatosPaciente {
  const DatosPaciente({
    required this.nombre,
    required this.whatsapp,
    this.edad,
    this.alergias,
    this.nota,
    this.consienteWhatsapp = true,
  });

  final String nombre;
  final String whatsapp;
  final int? edad;
  final String? alergias;
  final String? nota;
  final bool consienteWhatsapp;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'whatsapp': whatsapp,
    'edad': edad,
    'alergias': alergias,
    'nota': nota,
    'consienteWhatsapp': consienteWhatsapp,
  };
}

/// Página de resultados de la API.
class Pagina<T> {
  const Pagina({
    required this.contenido,
    required this.pagina,
    required this.totalElementos,
    required this.totalPaginas,
  });

  factory Pagina.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) mapear,
  ) => Pagina(
    contenido: (json['contenido'] as List<dynamic>)
        .map((e) => mapear(e as Map<String, dynamic>))
        .toList(),
    pagina: json['pagina'] as int,
    totalElementos: json['totalElementos'] as int,
    totalPaginas: json['totalPaginas'] as int,
  );

  final List<T> contenido;
  final int pagina;
  final int totalElementos;
  final int totalPaginas;

  bool get hayMas => pagina + 1 < totalPaginas;
}
