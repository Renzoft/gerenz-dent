package pe.gerenzdent.shared.config;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * "Hoy" según el consultorio (America/Lima), no según el servidor (UTC). A las 8 p. m. en Lima ya
 * es el día siguiente en UTC: sin esto, "mañana" y "vencidos" saldrían corridos un día.
 */
@Component
public class Calendario {

  private final Clock reloj;
  private final ZoneId zona;

  public Calendario(Clock reloj, @Value("${app.zona-horaria}") String zona) {
    this.reloj = reloj;
    this.zona = ZoneId.of(zona);
  }

  public LocalDate hoy() {
    return LocalDate.now(reloj.withZone(zona));
  }
}
