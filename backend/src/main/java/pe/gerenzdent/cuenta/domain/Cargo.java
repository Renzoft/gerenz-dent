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

/** Lo que el paciente debe por un plan (HU-21). Se genera solo; el doctor puede ajustarlo. */
@Entity
@Table(name = "cargo")
public class Cargo extends EntidadAuditable {

  public enum Concepto {
    /** Pago inicial (brackets). */
    INICIAL,
    /** Cuota cobrada al asistir a un control (brackets). */
    MENSUAL,
    /** Precio del tratamiento (fijo o por pieza). */
    TRATAMIENTO,
    /** Cargo manual: material adicional, otro procedimiento, etc. */
    OTRO
  }

  @Column(name = "plan_tratamiento_id", nullable = false, updatable = false)
  private UUID planId;

  @Column(name = "control_id", updatable = false)
  private UUID controlId;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 15)
  private Concepto concepto;

  @Column(length = 80)
  private String descripcion;

  @Column(nullable = false, precision = 10, scale = 2)
  private BigDecimal monto;

  @Column(nullable = false)
  private LocalDate fecha;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 10)
  private EstadoMovimiento estado;

  @Column(name = "motivo_anulacion", length = 140)
  private String motivoAnulacion;

  protected Cargo() {}

  public Cargo(
      UUID planId,
      UUID controlId,
      Concepto concepto,
      String descripcion,
      BigDecimal monto,
      LocalDate fecha) {
    if (concepto == Concepto.OTRO && Textos.limpiarOpcional(descripcion) == null) {
      throw new DatoInvalido(
          "descripcion", "Describe el cargo (por ejemplo, \"Resina adicional\").");
    }
    this.planId = planId;
    this.controlId = controlId;
    this.concepto = concepto;
    this.descripcion = Textos.limpiarOpcional(descripcion);
    this.monto = Montos.validar(monto, "monto", true);
    this.fecha = fecha;
    this.estado = EstadoMovimiento.VALIDO;
  }

  /** Descuento o corrección del monto (RN-08). */
  public void ajustarMonto(BigDecimal nuevoMonto) {
    exigirValido();
    this.monto = Montos.validar(nuevoMonto, "monto", true);
  }

  /** No se borra: queda anulado con su motivo (trazabilidad, HU-25). */
  public void anular(String motivo) {
    exigirValido();
    this.estado = EstadoMovimiento.ANULADO;
    this.motivoAnulacion = Movimientos.motivo(motivo);
  }

  public boolean esValido() {
    return estado == EstadoMovimiento.VALIDO;
  }

  private void exigirValido() {
    if (!esValido()) {
      throw new Conflicto("Este cargo ya está anulado.", Map.of());
    }
  }

  public UUID getPlanId() {
    return planId;
  }

  public UUID getControlId() {
    return controlId;
  }

  public Concepto getConcepto() {
    return concepto;
  }

  public String getDescripcion() {
    return descripcion;
  }

  public BigDecimal getMonto() {
    return monto;
  }

  public LocalDate getFecha() {
    return fecha;
  }

  public EstadoMovimiento getEstado() {
    return estado;
  }

  public String getMotivoAnulacion() {
    return motivoAnulacion;
  }
}
