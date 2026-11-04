package pe.gerenzdent.tratamiento.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;
import pe.gerenzdent.shared.domain.EntidadAuditable;

/** Tratamiento del catálogo del consultorio (HU-08, HU-09). */
@Entity
@Table(name = "tratamiento")
public class Tratamiento extends EntidadAuditable {

  @Column(nullable = false, length = 80)
  private String nombre;

  @Enumerated(EnumType.STRING)
  @Column(name = "tipo_precio", nullable = false, length = 25)
  private TipoPrecio tipoPrecio;

  @Column(name = "precio_base", precision = 10, scale = 2)
  private BigDecimal precioBase;

  @Column(name = "precio_mensual", precision = 10, scale = 2)
  private BigDecimal precioMensual;

  @Column(name = "intervalo_control_dias")
  private Integer intervaloControlDias;

  @Column(name = "edad_maxima_control")
  private Integer edadMaximaControl;

  @Column(nullable = false)
  private int orden;

  @Column(nullable = false)
  private boolean activo;

  protected Tratamiento() {}

  public Tratamiento(
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {
    this.nombre = nombre;
    this.tipoPrecio = tipoPrecio;
    this.precioBase = precioBase;
    this.precioMensual = precioMensual;
    this.intervaloControlDias = intervaloControlDias;
    this.edadMaximaControl = edadMaximaControl;
    this.activo = true;
  }

  /**
   * Fecha sugerida para el próximo control (HU-09, RN-03, RN-07).
   *
   * @param desde fecha base (normalmente hoy)
   * @param edadPaciente edad registrada del paciente, o {@code null} si no se conoce
   * @return vacío si el tratamiento no tiene intervalo, o si solo aplica a niños y el paciente no
   *     tiene edad registrada o supera el límite
   */
  public Optional<LocalDate> fechaSugerida(LocalDate desde, Integer edadPaciente) {
    if (intervaloControlDias == null) {
      return Optional.empty();
    }
    if (edadMaximaControl != null && (edadPaciente == null || edadPaciente > edadMaximaControl)) {
      return Optional.empty();
    }
    return Optional.of(desde.plusDays(intervaloControlDias));
  }

  public boolean esPorPieza() {
    return tipoPrecio == TipoPrecio.POR_PIEZA;
  }

  public String getNombre() {
    return nombre;
  }

  public TipoPrecio getTipoPrecio() {
    return tipoPrecio;
  }

  public BigDecimal getPrecioBase() {
    return precioBase;
  }

  public BigDecimal getPrecioMensual() {
    return precioMensual;
  }

  public Integer getIntervaloControlDias() {
    return intervaloControlDias;
  }

  public Integer getEdadMaximaControl() {
    return edadMaximaControl;
  }

  public int getOrden() {
    return orden;
  }

  public boolean isActivo() {
    return activo;
  }
}
