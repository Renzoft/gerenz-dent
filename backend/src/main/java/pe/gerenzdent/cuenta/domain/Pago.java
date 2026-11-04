package pe.gerenzdent.cuenta.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;
import pe.gerenzdent.shared.domain.EntidadAuditable;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Textos;

/** Abono del paciente a un plan (HU-22). */
@Entity
@Table(name = "pago")
public class Pago extends EntidadAuditable {

  public static final int NOTA_MAX = 140;

  public enum Medio {
    EFECTIVO,
    YAPE,
    PLIN,
    TRANSFERENCIA,
    TARJETA,
    OTRO
  }

  @Column(name = "plan_tratamiento_id", nullable = false, updatable = false)
  private UUID planId;

  @Column(nullable = false, precision = 10, scale = 2)
  private BigDecimal monto;

  @Column(nullable = false)
  private LocalDate fecha;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 15)
  private Medio medio;

  @Column(length = NOTA_MAX)
  private String nota;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 10)
  private EstadoMovimiento estado;

  @Column(name = "motivo_anulacion", length = 140)
  private String motivoAnulacion;

  protected Pago() {}

  public Pago(
      UUID planId, BigDecimal monto, LocalDate fecha, Medio medio, String nota, LocalDate hoy) {
    if (fecha == null || fecha.isAfter(hoy)) {
      throw new DatoInvalido("fecha", "La fecha del pago no puede ser futura.");
    }
    String notaLimpia = Textos.limpiarOpcional(nota);
    if (notaLimpia != null && notaLimpia.length() > NOTA_MAX) {
      throw new DatoInvalido("nota", "Máximo 140 caracteres.");
    }
    this.planId = planId;
    this.monto = Montos.validar(monto, "monto", false);
    this.fecha = fecha;
    this.medio = medio == null ? Medio.EFECTIVO : medio;
    this.nota = notaLimpia;
    this.estado = EstadoMovimiento.VALIDO;
  }

  /** Pago registrado por error: no se borra, queda anulado (HU-25). */
  public void anular(String motivo) {
    if (!esValido()) {
      throw new Conflicto("Este pago ya está anulado.", Map.of());
    }
    this.estado = EstadoMovimiento.ANULADO;
    this.motivoAnulacion = Movimientos.motivo(motivo);
  }

  public boolean esValido() {
    return estado == EstadoMovimiento.VALIDO;
  }

  public UUID getPlanId() {
    return planId;
  }

  public BigDecimal getMonto() {
    return monto;
  }

  public LocalDate getFecha() {
    return fecha;
  }

  public Medio getMedio() {
    return medio;
  }

  public String getNota() {
    return nota;
  }

  public EstadoMovimiento getEstado() {
    return estado;
  }

  public String getMotivoAnulacion() {
    return motivoAnulacion;
  }
}
