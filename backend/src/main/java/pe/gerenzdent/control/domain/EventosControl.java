package pe.gerenzdent.control.domain;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Eventos de dominio que publica el módulo de controles. Otros módulos reaccionan sin que este los
 * conozca (p. ej. "cuenta" genera los cargos). Se procesan en la misma transacción: si un oyente
 * falla, no se guarda nada.
 */
public final class EventosControl {

  private EventosControl() {}

  /**
   * Se creó un plan (primer control de ese tratamiento para el paciente).
   *
   * @param costoAcordado monto que indicó el doctor; {@code null} = el del catálogo
   * @param pagoInicial lo que pagó el paciente al registrarse; {@code null} = nada
   * @param medioPagoInicial nombre del medio (EFECTIVO, YAPE…); {@code null} = efectivo
   */
  public record PlanCreado(
      PlanTratamiento plan,
      BigDecimal costoAcordado,
      BigDecimal pagoInicial,
      String medioPagoInicial,
      LocalDate fecha) {}

  /** El paciente asistió a un control (brackets: se cobra la cuota mensual). */
  public record ControlAsistido(Control control, LocalDate fecha) {}
}
