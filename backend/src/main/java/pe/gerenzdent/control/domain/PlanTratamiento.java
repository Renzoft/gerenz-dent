package pe.gerenzdent.control.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import pe.gerenzdent.shared.domain.EntidadAuditable;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

/**
 * "Juan · Brackets": une al paciente con un tratamiento. De él cuelgan los controles y, desde la
 * iteración 4, los cargos y pagos. En la app es invisible: el doctor solo elige paciente +
 * tratamiento.
 */
@Entity
@Table(name = "plan_tratamiento")
public class PlanTratamiento extends EntidadAuditable {

  public static final int PIEZAS_MAX = 32;

  public enum Estado {
    ACTIVO,
    FINALIZADO
  }

  @Column(name = "paciente_id", nullable = false, updatable = false)
  private UUID pacienteId;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "tratamiento_id", nullable = false, updatable = false)
  private Tratamiento tratamiento;

  private Integer piezas;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 15)
  private Estado estado;

  @Column(name = "fecha_inicio", nullable = false)
  private LocalDate fechaInicio;

  protected PlanTratamiento() {}

  public PlanTratamiento(
      UUID pacienteId, Tratamiento tratamiento, Integer piezas, LocalDate fechaInicio) {
    this.pacienteId = pacienteId;
    this.tratamiento = tratamiento;
    this.piezas = validarPiezas(tratamiento, piezas);
    this.estado = Estado.ACTIVO;
    this.fechaInicio = fechaInicio;
  }

  /** Solo los tratamientos por pieza guardan piezas (1 por defecto). */
  private static Integer validarPiezas(Tratamiento tratamiento, Integer piezas) {
    if (!tratamiento.esPorPieza()) {
      return null;
    }
    int valor = piezas == null ? 1 : piezas;
    if (valor < 1 || valor > PIEZAS_MAX) {
      throw new DatoInvalido(
          "piezas", "Las piezas deben estar entre 1 y %d.".formatted(PIEZAS_MAX));
    }
    return valor;
  }

  public UUID getPacienteId() {
    return pacienteId;
  }

  public Tratamiento getTratamiento() {
    return tratamiento;
  }

  public Integer getPiezas() {
    return piezas;
  }

  public Estado getEstado() {
    return estado;
  }

  public LocalDate getFechaInicio() {
    return fechaInicio;
  }
}
