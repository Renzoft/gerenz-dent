package pe.gerenzdent.auth.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalTime;
import java.util.Locale;
import pe.gerenzdent.shared.domain.EntidadAuditable;

/** Usuario del consultorio (el doctor). Controla el bloqueo por intentos fallidos (HU-01). */
@Entity
@Table(name = "usuario")
public class Usuario extends EntidadAuditable {

  private static final LocalTime HORA_NOTIFICACION_POR_DEFECTO = LocalTime.of(16, 30);

  @Column(nullable = false, length = 120)
  private String email;

  @Column(name = "password_hash", nullable = false, length = 100)
  private String passwordHash;

  @Column(nullable = false, length = 80)
  private String nombre;

  @Column(name = "hora_notificacion", nullable = false)
  private LocalTime horaNotificacion;

  @Column(name = "intentos_fallidos", nullable = false)
  private int intentosFallidos;

  @Column(name = "bloqueado_hasta")
  private Instant bloqueadoHasta;

  protected Usuario() {}

  public Usuario(String email, String passwordHash, String nombre) {
    this.email = normalizarEmail(email);
    this.passwordHash = passwordHash;
    this.nombre = nombre;
    this.horaNotificacion = HORA_NOTIFICACION_POR_DEFECTO;
  }

  public static String normalizarEmail(String email) {
    return email == null ? null : email.strip().toLowerCase(Locale.ROOT);
  }

  public boolean estaBloqueado(Instant ahora) {
    return bloqueadoHasta != null && ahora.isBefore(bloqueadoHasta);
  }

  /** Minutos que faltan para desbloquear (redondeado hacia arriba, mínimo 1). */
  public long minutosDeBloqueoRestantes(Instant ahora) {
    if (!estaBloqueado(ahora)) {
      return 0;
    }
    long segundos = Duration.between(ahora, bloqueadoHasta).toSeconds();
    return Math.max(1, (segundos + 59) / 60);
  }

  /** Suma un intento fallido; al llegar al máximo bloquea el acceso durante {@code bloqueo}. */
  public void registrarIntentoFallido(Instant ahora, int maxIntentos, Duration bloqueo) {
    if (bloqueadoHasta != null && !ahora.isBefore(bloqueadoHasta)) {
      // El bloqueo anterior ya venció: se empieza a contar de nuevo.
      bloqueadoHasta = null;
      intentosFallidos = 0;
    }
    intentosFallidos++;
    if (intentosFallidos >= maxIntentos) {
      bloqueadoHasta = ahora.plus(bloqueo);
      intentosFallidos = 0;
    }
  }

  /** Hora del aviso diario en el teléfono (HU-20). */
  public void cambiarHoraNotificacion(LocalTime hora) {
    if (hora == null) {
      throw new pe.gerenzdent.shared.domain.Excepciones.DatoInvalido(
          "horaNotificacion", "Elige la hora del aviso.");
    }
    this.horaNotificacion = hora.withSecond(0).withNano(0);
  }

  public void registrarLoginExitoso() {
    intentosFallidos = 0;
    bloqueadoHasta = null;
  }

  public String getEmail() {
    return email;
  }

  public String getPasswordHash() {
    return passwordHash;
  }

  public String getNombre() {
    return nombre;
  }

  public LocalTime getHoraNotificacion() {
    return horaNotificacion;
  }

  public int getIntentosFallidos() {
    return intentosFallidos;
  }
}
