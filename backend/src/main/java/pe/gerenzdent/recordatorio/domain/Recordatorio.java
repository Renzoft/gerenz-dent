package pe.gerenzdent.recordatorio.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import pe.gerenzdent.shared.domain.EntidadAuditable;

/** Mensaje que el doctor confirmó haber enviado (HU-17, HU-18). */
@Entity
@Table(name = "recordatorio")
public class Recordatorio extends EntidadAuditable {

  public enum Tipo {
    /** Antes de la cita (el día anterior). */
    PREVIO,
    /** Después de la fecha, si el paciente no vino. */
    SEGUIMIENTO
  }

  @Column(name = "control_id", nullable = false, updatable = false)
  private UUID controlId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 15)
  private Tipo tipo;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 20)
  private ProveedorNotificaciones.Canal canal;

  @Column(name = "enviado_en", nullable = false)
  private Instant enviadoEn;

  protected Recordatorio() {}

  public Recordatorio(
      UUID controlId, Tipo tipo, ProveedorNotificaciones.Canal canal, Instant enviadoEn) {
    this.controlId = controlId;
    this.tipo = tipo;
    this.canal = canal;
    this.enviadoEn = enviadoEn;
  }

  public UUID getControlId() {
    return controlId;
  }

  public Tipo getTipo() {
    return tipo;
  }

  public ProveedorNotificaciones.Canal getCanal() {
    return canal;
  }

  public Instant getEnviadoEn() {
    return enviadoEn;
  }
}
