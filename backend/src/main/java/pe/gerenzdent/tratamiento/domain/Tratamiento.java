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
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

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
    aplicar(nombre, tipoPrecio, precioBase, precioMensual, intervaloControlDias, edadMaximaControl);
    this.activo = true;
  }

  /**
   * Edición desde la app (HU-10). Cambiar el precio solo afecta a los tratamientos que se inicien
   * después: los cargos ya generados no cambian.
   */
  public void actualizar(
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {
    aplicar(nombre, tipoPrecio, precioBase, precioMensual, intervaloControlDias, edadMaximaControl);
  }

  /** Un tratamiento inactivo deja de ofrecerse al agendar; sus planes existentes siguen igual. */
  public void cambiarActivo(boolean activo) {
    this.activo = activo;
  }

  public void ubicarAlFinal(int orden) {
    this.orden = orden;
  }

  private void aplicar(
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {
    String limpio = pe.gerenzdent.shared.domain.Textos.limpiar(nombre);
    if (limpio == null || limpio.length() < 2 || limpio.length() > 80) {
      throw new DatoInvalido("nombre", "El nombre debe tener entre 2 y 80 caracteres.");
    }
    if (tipoPrecio == null) {
      throw new DatoInvalido("tipoPrecio", "Elige cómo se cobra.");
    }
    BigDecimal base = precio(precioBase, "precioBase");
    BigDecimal mensual = precio(precioMensual, "precioMensual");
    if (tipoPrecio == TipoPrecio.INICIAL_MAS_MENSUAL && mensual == null) {
      throw new DatoInvalido("precioMensual", "Indica la cuota mensual.");
    }
    if (intervaloControlDias != null && (intervaloControlDias < 1 || intervaloControlDias > 730)) {
      throw new DatoInvalido("intervaloControlDias", "El intervalo debe estar entre 1 y 730 días.");
    }
    if (edadMaximaControl != null && (edadMaximaControl < 0 || edadMaximaControl > 120)) {
      throw new DatoInvalido("edadMaximaControl", "La edad debe estar entre 0 y 120.");
    }
    this.nombre = limpio;
    this.tipoPrecio = tipoPrecio;
    this.precioBase = base;
    this.precioMensual = tipoPrecio == TipoPrecio.INICIAL_MAS_MENSUAL ? mensual : null;
    this.intervaloControlDias = intervaloControlDias;
    // Sin intervalo no hay sugerencia, así que la edad máxima no aplica.
    this.edadMaximaControl = intervaloControlDias == null ? null : edadMaximaControl;
  }

  private static BigDecimal precio(BigDecimal valor, String campo) {
    if (valor == null) {
      return null;
    }
    BigDecimal redondeado = valor.setScale(2, java.math.RoundingMode.HALF_UP);
    if (redondeado.signum() < 0 || redondeado.compareTo(new BigDecimal("99999.99")) > 0) {
      throw new DatoInvalido(campo, "El precio debe estar entre S/ 0 y S/ 99,999.99.");
    }
    return redondeado;
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
