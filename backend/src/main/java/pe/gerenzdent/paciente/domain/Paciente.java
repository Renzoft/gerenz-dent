package pe.gerenzdent.paciente.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.UUID;
import pe.gerenzdent.shared.domain.EntidadAuditable;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Textos;

/** Paciente del consultorio (HU-02 a HU-06). Solo nombre y WhatsApp son obligatorios. */
@Entity
@Table(name = "paciente")
public class Paciente extends EntidadAuditable {

  public static final int NOMBRE_MIN = 2;
  public static final int NOMBRE_MAX = 80;
  public static final int EDAD_MAX = 120;
  public static final int ALERGIAS_MAX = 200;
  public static final int NOTA_MAX = 300;

  @Column(name = "usuario_id", nullable = false, updatable = false)
  private UUID usuarioId;

  @Column(nullable = false, length = NOMBRE_MAX)
  private String nombre;

  @Column(name = "nombre_busqueda", nullable = false, length = NOMBRE_MAX)
  private String nombreBusqueda;

  @Column(nullable = false, length = 16)
  private String whatsapp;

  private Integer edad;

  @Column(length = ALERGIAS_MAX)
  private String alergias;

  @Column(length = NOTA_MAX)
  private String nota;

  @Column(name = "consiente_whatsapp", nullable = false)
  private boolean consienteWhatsapp;

  @Column(nullable = false)
  private boolean archivado;

  protected Paciente() {}

  public Paciente(UUID usuarioId, DatosPaciente datos) {
    this.usuarioId = usuarioId;
    aplicar(datos);
  }

  public void actualizar(DatosPaciente datos) {
    aplicar(datos);
  }

  public void archivar() {
    archivado = true;
  }

  public void desarchivar() {
    archivado = false;
  }

  public boolean tieneAlergias() {
    return alergias != null;
  }

  private void aplicar(DatosPaciente datos) {
    String nombreLimpio = Textos.limpiar(datos.nombre());
    if (nombreLimpio == null
        || nombreLimpio.length() < NOMBRE_MIN
        || nombreLimpio.length() > NOMBRE_MAX) {
      throw new DatoInvalido(
          "nombre",
          "El nombre debe tener entre %d y %d caracteres.".formatted(NOMBRE_MIN, NOMBRE_MAX));
    }
    if (datos.edad() != null && (datos.edad() < 0 || datos.edad() > EDAD_MAX)) {
      throw new DatoInvalido("edad", "La edad debe estar entre 0 y %d.".formatted(EDAD_MAX));
    }
    this.nombre = nombreLimpio;
    this.nombreBusqueda = Textos.paraBusqueda(nombreLimpio);
    this.whatsapp = NumeroWhatsapp.normalizar(datos.whatsapp());
    this.edad = datos.edad();
    this.alergias = opcional(datos.alergias(), "alergias", ALERGIAS_MAX);
    this.nota = opcional(datos.nota(), "nota", NOTA_MAX);
    this.consienteWhatsapp = datos.consienteWhatsapp();
  }

  private static String opcional(String valor, String campo, int maximo) {
    String limpio = Textos.limpiarOpcional(valor);
    if (limpio != null && limpio.length() > maximo) {
      throw new DatoInvalido(campo, "Máximo %d caracteres.".formatted(maximo));
    }
    return limpio;
  }

  public UUID getUsuarioId() {
    return usuarioId;
  }

  public String getNombre() {
    return nombre;
  }

  public String getWhatsapp() {
    return whatsapp;
  }

  public Integer getEdad() {
    return edad;
  }

  public String getAlergias() {
    return alergias;
  }

  public String getNota() {
    return nota;
  }

  public boolean isConsienteWhatsapp() {
    return consienteWhatsapp;
  }

  public boolean isArchivado() {
    return archivado;
  }
}
