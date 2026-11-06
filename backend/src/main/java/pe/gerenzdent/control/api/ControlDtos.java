package pe.gerenzdent.control.api;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;
import pe.gerenzdent.control.application.ControlService.ControlConPaciente;
import pe.gerenzdent.control.application.ControlService.NuevoControl;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.control.domain.EstadoControl;
import pe.gerenzdent.control.domain.PlanTratamiento;
import pe.gerenzdent.paciente.domain.Paciente;

/** Contratos JSON del módulo de controles. */
public final class ControlDtos {

  private ControlDtos() {}

  public record NuevoControlRequest(
      @NotNull(message = "Indica el paciente") UUID pacienteId,
      @NotNull(message = "Elige el tratamiento") UUID tratamientoId,
      @NotNull(message = "Elige la fecha del control") LocalDate fecha,
      LocalTime hora,
      @Size(max = Control.NOTA_MAX, message = "Máximo 140 caracteres") String nota,
      @Min(value = 1, message = "Mínimo 1 pieza")
          @Max(value = PlanTratamiento.PIEZAS_MAX, message = "Máximo 32 piezas")
          Integer piezas,
      @jakarta.validation.constraints.DecimalMin(
              value = "0.00",
              message = "El costo no puede ser negativo")
          java.math.BigDecimal costo,
      @jakarta.validation.constraints.DecimalMin(
              value = "0.01",
              message = "El pago debe ser mayor a 0")
          java.math.BigDecimal pagoInicial,
      String medioPago) {

    NuevoControl aComando() {
      return new NuevoControl(
          pacienteId, tratamientoId, fecha, hora, nota, piezas, costo, pagoInicial, medioPago);
    }
  }

  public record CambioEstadoRequest(@NotNull(message = "Indica el estado") EstadoControl estado) {}

  public record ReprogramarRequest(
      @NotNull(message = "Elige la nueva fecha") LocalDate fecha, LocalTime hora) {}

  public record TratamientoResumen(UUID id, String nombre) {}

  public record PacienteResumen(
      UUID id, String nombre, String whatsapp, boolean consienteWhatsapp) {
    static PacienteResumen de(Paciente p) {
      return new PacienteResumen(
          p.getId(), p.getNombre(), p.getWhatsapp(), p.isConsienteWhatsapp());
    }
  }

  public record ControlResponse(
      UUID id,
      UUID planId,
      UUID pacienteId,
      LocalDate fecha,
      LocalTime hora,
      String nota,
      EstadoControl estado,
      LocalDate cerradoEn,
      boolean abierto,
      boolean vencido,
      long diasAtraso,
      TratamientoResumen tratamiento,
      Integer piezas,
      PacienteResumen paciente) {

    static ControlResponse de(Control c, LocalDate hoy) {
      return de(c, null, hoy);
    }

    static ControlResponse de(ControlConPaciente cp, LocalDate hoy) {
      return de(cp.control(), cp.paciente(), hoy);
    }

    private static ControlResponse de(Control c, Paciente paciente, LocalDate hoy) {
      PlanTratamiento plan = c.getPlan();
      return new ControlResponse(
          c.getId(),
          plan.getId(),
          plan.getPacienteId(),
          c.getFecha(),
          c.getHora(),
          c.getNota(),
          c.getEstado(),
          c.getCerradoEn(),
          c.getEstado().esAbierto(),
          c.estaVencido(hoy),
          c.diasDeAtraso(hoy),
          new TratamientoResumen(plan.getTratamiento().getId(), plan.getTratamiento().getNombre()),
          plan.getPiezas(),
          paciente == null ? null : PacienteResumen.de(paciente));
    }
  }

  public record CambioEstadoResponse(ControlResponse control, LocalDate siguienteFechaSugerida) {}

  /** "No vino": fecha (y hora) del siguiente control, o nada si todavía no se sabe. */
  public record NoVinoRequest(LocalDate fecha, LocalTime hora) {}

  public record NoVinoResponse(ControlResponse control, ControlResponse siguiente) {}

  public record SugerenciaResponse(LocalDate fecha) {}
}
