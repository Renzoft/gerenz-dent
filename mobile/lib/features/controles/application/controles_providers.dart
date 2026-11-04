import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Pasó la fecha y el paciente no vino.
final vencidosProvider = FutureProvider.autoDispose<List<Control>>(
  (ref) => ref.read(controlesRepositoryProvider).vencidos(),
  retry: (intento, error) => null,
);

/// Recarga todo lo que muestra controles después de un cambio.
void refrescarControles(WidgetRef ref, [String? pacienteId]) {
  ref.invalidate(agendaSemanaProvider);
  ref.invalidate(vencidosProvider);
  if (pacienteId != null) ref.invalidate(historialPacienteProvider(pacienteId));
}
