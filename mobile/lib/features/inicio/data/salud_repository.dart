import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Consulta si la API del consultorio está disponible.
class SaludRepository {
  SaludRepository(this._dio);

  final Dio _dio;

  Future<bool> servidorDisponible() async {
    final respuesta = await _dio.get<Map<String, dynamic>>('/actuator/health');
    return respuesta.data?['status'] == 'UP';
  }
}

final saludRepositoryProvider = Provider<SaludRepository>(
  (ref) => SaludRepository(ref.watch(dioBaseProvider)),
);

/// `true` si la API respondió "UP". Si falla, el estado queda en error y la
/// pantalla ofrece reintentar.
final estadoServidorProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(saludRepositoryProvider).servidorDisponible(),
  retry: (intento, error) => null,
);
