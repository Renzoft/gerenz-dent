import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/tratamiento.dart';

class TratamientosRepository {
  TratamientosRepository(this._dio);

  final Dio _dio;

  /// Solo activos (para agendar) o [todos] (pantalla del catálogo).
  Future<List<Tratamiento>> listar({bool todos = false}) async {
    try {
      final r = await _dio.get<List<dynamic>>(
        '/api/v1/tratamientos',
        queryParameters: {if (todos) 'todos': true},
      );
      return r.data!
          .map((e) => Tratamiento.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  Future<Tratamiento> guardar(DatosTratamiento datos, {String? id}) async {
    try {
      final r = id == null
          ? await _dio.post<Map<String, dynamic>>(
              '/api/v1/tratamientos',
              data: datos.toJson(),
            )
          : await _dio.put<Map<String, dynamic>>(
              '/api/v1/tratamientos/$id',
              data: datos.toJson(),
            );
      return Tratamiento.fromJson(r.data!);
    } catch (e) {
      throw ApiError.desde(e);
    }
  }

  Future<Tratamiento> cambiarActivo(String id, {required bool activo}) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/tratamientos/$id/activo',
        data: {'activo': activo},
      );
      return Tratamiento.fromJson(r.data!);
    } catch (e) {
      throw ApiError.desde(e);
    }
  }
}

/// Datos que se editan en el catálogo.
class DatosTratamiento {
  const DatosTratamiento({
    required this.nombre,
    required this.tipoPrecio,
    this.precioBase,
    this.precioMensual,
    this.intervaloControlDias,
    this.edadMaximaControl,
  });

  final String nombre;
  final TipoPrecio tipoPrecio;
  final double? precioBase;
  final double? precioMensual;
  final int? intervaloControlDias;
  final int? edadMaximaControl;

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'tipoPrecio': tipoPrecio.api,
    'precioBase': precioBase,
    'precioMensual': precioMensual,
    'intervaloControlDias': intervaloControlDias,
    'edadMaximaControl': edadMaximaControl,
  };
}

final tratamientosRepositoryProvider = Provider<TratamientosRepository>(
  (ref) => TratamientosRepository(ref.watch(dioProvider)),
);

/// Catálogo completo, con los inactivos (pantalla de edición): primero los
/// activos y, dentro de cada grupo, de la A a la Z.
final catalogoCompletoProvider = FutureProvider.autoDispose<List<Tratamiento>>((
  ref,
) async {
  final lista = await ref
      .watch(tratamientosRepositoryProvider)
      .listar(todos: true);
  return ordenarAlfabeticamente(lista, activosPrimero: true);
}, retry: (intento, error) => null);

/// El catálogo casi no cambia: se carga una vez por sesión. De la A a la Z.
final catalogoProvider = FutureProvider<List<Tratamiento>>(
  (ref) async => ordenarAlfabeticamente(
    await ref.watch(tratamientosRepositoryProvider).listar(),
  ),
  retry: (intento, error) => null,
);

/// Ordena por nombre de la A a la Z sin que importen tildes ni mayúsculas
/// ("Ácido…" va con la A, "ortodoncia" junto a "Ortodoncia").
List<Tratamiento> ordenarAlfabeticamente(
  List<Tratamiento> lista, {
  bool activosPrimero = false,
}) {
  final ordenada = [...lista];
  ordenada.sort((a, b) {
    if (activosPrimero && a.activo != b.activo) return a.activo ? -1 : 1;
    final porNombre = claveDeOrden(a.nombre).compareTo(claveDeOrden(b.nombre));
    return porNombre != 0 ? porNombre : a.nombre.compareTo(b.nombre);
  });
  return ordenada;
}

/// Minúsculas y sin tildes; la ñ va después de la n, como en el diccionario.
String claveDeOrden(String texto) {
  const tildes = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', //
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
    'ñ': 'n~',
  };
  final b = StringBuffer();
  for (final letra in texto.trim().toLowerCase().split('')) {
    b.write(tildes[letra] ?? letra);
  }
  return b.toString();
}
