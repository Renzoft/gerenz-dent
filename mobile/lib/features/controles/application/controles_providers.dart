import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cuenta/application/cuenta_providers.dart';
import '../data/controles_repository.dart';
import '../domain/control.dart';

/// Controles de un paciente (ficha): abiertos primero, luego el historial.
final historialPacienteProvider = FutureProvider.autoDispose
    .family<List<Control>, String>(
      (ref, pacienteId) =>
          ref.read(controlesRepositoryProvider).historial(pacienteId),
      retry: (intento, error) => null,
    );

/// Próximos 7 días (Inicio).
final agendaSemanaProvider = FutureProvider.autoDispose<List<Control>>(
  (ref) => ref.read(controlesRepositoryProvider).agenda(),
  retry: (intento, error) => null,
);

/// Calendario: todos los controles de un mes (abiertos, asistió y no vino).
/// La clave es el primer día del mes.
final agendaMesProvider = FutureProvider.autoDispose
    .family<List<Control>, DateTime>(
      (ref, mes) => ref
          .read(controlesRepositoryProvider)
          .agenda(
            desde: DateTime(mes.year, mes.month),
            hasta: DateTime(mes.year, mes.month + 1, 0),
            cerrados: true,
          ),
      retry: (intento, error) => null,
    );

/// Pasó la fecha y el paciente no vino.
final vencidosProvider = FutureProvider.autoDispose<List<Control>>(
  (ref) => ref.read(controlesRepositoryProvider).vencidos(),
  retry: (intento, error) => null,
);

/// Recarga todo lo que muestra controles después de un cambio.
/// Agendar y marcar "asistió" generan cargos: también se recarga la cuenta.
void refrescarControles(WidgetRef ref, [String? pacienteId]) {
  ref.invalidate(agendaSemanaProvider);
  ref.invalidate(agendaMesProvider);
  ref.invalidate(vencidosProvider);
  ref.invalidate(deudasProvider);
  if (pacienteId != null) {
    ref.invalidate(historialPacienteProvider(pacienteId));
    ref.invalidate(cuentaPacienteProvider(pacienteId));
  }
}
