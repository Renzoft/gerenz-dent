package pe.gerenzdent.control.domain;

import java.util.Set;

/**
 * Estados de un control (docs/planificacion/03-modelo-de-datos.md §3).
 *
 * <p>Abiertos: PENDIENTE, RECORDADO, CONFIRMADO. Finales: ASISTIO, NO_ASISTIO, CANCELADO. "Vencido"
 * no es un estado: es un control abierto cuya fecha ya pasó.
 */
public enum EstadoControl {
  PENDIENTE,
  RECORDADO,
  CONFIRMADO,
  ASISTIO,
  NO_ASISTIO,
  CANCELADO;

  private static final Set<EstadoControl> ABIERTOS = Set.of(PENDIENTE, RECORDADO, CONFIRMADO);

  public boolean esAbierto() {
    return ABIERTOS.contains(this);
  }

  /**
   * Transiciones permitidas. Volver a PENDIENTE solo se hace reprogramando. RECORDADO→RECORDADO se
   * permite para registrar un mensaje de seguimiento.
   */
  public boolean puedePasarA(EstadoControl destino) {
    if (!esAbierto()) {
      return false;
    }
    return switch (destino) {
      case PENDIENTE -> false;
      case RECORDADO -> this == PENDIENTE || this == RECORDADO;
      case CONFIRMADO -> this == PENDIENTE || this == RECORDADO;
      case ASISTIO, NO_ASISTIO, CANCELADO -> true;
    };
  }

  public static Set<EstadoControl> abiertos() {
    return ABIERTOS;
  }
}
