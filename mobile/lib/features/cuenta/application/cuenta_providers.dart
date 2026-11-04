import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cuenta_repository.dart';
import '../domain/cuenta.dart';

/// Cuenta de un paciente (ficha).
final cuentaPacienteProvider = FutureProvider.autoDispose
    .family<CuentaPaciente, String>(
      (ref, pacienteId) =>
          ref.read(cuentaRepositoryProvider).cuenta(pacienteId),
      retry: (intento, error) => null,
    );

/// Pestaña Deudas.
final deudasProvider = FutureProvider.autoDispose<ResumenDeudas>(
  (ref) => ref.read(cuentaRepositoryProvider).deudas(),
  retry: (intento, error) => null,
);

/// Recarga la cuenta del paciente y la lista de deudas tras un cambio.
void refrescarCuenta(WidgetRef ref, String pacienteId) {
  ref.invalidate(cuentaPacienteProvider(pacienteId));
  ref.invalidate(deudasProvider);
}
