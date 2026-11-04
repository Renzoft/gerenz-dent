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
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import pe.gerenzdent.shared.domain.EntidadAuditable;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Textos;

/** Próximo control (cita aproximada) de un plan de tratamiento (HU-11 a HU-14). */
@Entity
@Table(name = "control")
public class Control extends EntidadAuditable {

  public static final int NOTA_MAX = 140;

  @ManyToOne(fetch = FetchType.LAZY, optional = false)
  @JoinColumn(name = "plan_tratamiento_id", nullable = false, updatable = false)
  private PlanTratamiento plan;

  @Column(nullable = false)
  private LocalDate fecha;

  private LocalTime hora;

  @Column(length = NOTA_MAX)
  private String nota;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 15)
  private EstadoControl estado;

  protected Control() {}

  public Control(
      PlanTratamiento plan, LocalDate fecha, LocalTime hora, String nota, LocalDate hoy) {
    this.plan = plan;
    this.estado = EstadoControl.PENDIENTE;
    asignarFecha(fecha, hora, hoy);
    this.nota = validarNota(nota);
  }

  /** Cambia el estado si la transición está permitida (si no, 409). */
  public void cambiarEstado(EstadoControl destino) {
    if (!estado.puedePasarA(destino)) {
      throw new Conflicto(
          "No se puede cambiar el control de %s a %s.".formatted(texto(estado), texto(destino)),
          Map.of("estadoActual", estado.name()));
    }
    estado = destino;
  }

  /** Cambia la fecha (y hora) y vuelve a PENDIENTE (HU-14). */
  public void reprogramar(LocalDate nuevaFecha, LocalTime nuevaHora, LocalDate hoy) {
    if (!estado.esAbierto()) {
      throw new Conflicto(
          "Este control ya está cerrado (%s); agenda uno nuevo.".formatted(texto(estado)),
          Map.of("estadoActual", estado.name()));
    }
    asignarFecha(nuevaFecha, nuevaHora, hoy);
    estado = EstadoControl.PENDIENTE;
  }

  /** Abierto y con fecha pasada: el paciente no vino (todavía). */
  public boolean estaVencido(LocalDate hoy) {
    return estado.esAbierto() && fecha.isBefore(hoy);
  }

  public long diasDeAtraso(LocalDate hoy) {
    return estaVencido(hoy) ? ChronoUnit.DAYS.between(fecha, hoy) : 0;
  }

  private void asignarFecha(LocalDate nuevaFecha, LocalTime nuevaHora, LocalDate hoy) {
    if (nuevaFecha == null) {
      throw new DatoInvalido("fecha", "Elige la fecha del control.");
    }
    if (nuevaFecha.isBefore(hoy)) {
      throw new DatoInvalido("fecha", "La fecha no puede ser anterior a hoy.");
    }
    this.fecha = nuevaFecha;
    this.hora = nuevaHora == null ? null : nuevaHora.withSecond(0).withNano(0);
  }

  private static String validarNota(String nota) {
    String limpia = Textos.limpiarOpcional(nota);
    if (limpia != null && limpia.length() > NOTA_MAX) {
      throw new DatoInvalido("nota", "Máximo %d caracteres.".formatted(NOTA_MAX));
    }
    return limpia;
  }

  private static String texto(EstadoControl e) {
    return switch (e) {
      case PENDIENTE -> "pendiente";
      case RECORDADO -> "recordado";
      case CONFIRMADO -> "confirmado";
      case ASISTIO -> "asistió";
      case NO_ASISTIO -> "no asistió";
      case CANCELADO -> "cancelado";
    };
  }

  public PlanTratamiento getPlan() {
    return plan;
  }

  public LocalDate getFecha() {
    return fecha;
  }

  public LocalTime getHora() {
    return hora;
  }

  public String getNota() {
    return nota;
  }

  public EstadoControl getEstado() {
    return estado;
  }
}
