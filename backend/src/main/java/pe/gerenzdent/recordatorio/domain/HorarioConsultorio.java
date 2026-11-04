package pe.gerenzdent.recordatorio.domain;

import java.time.DayOfWeek;
import java.time.LocalTime;

/**
 * Horario de atención de GERENZ DENT (docs/planificacion/01-vision-y-alcance.md §4, RN-04): lunes a
 * viernes desde las 18:00, sábados desde las 16:00 y domingos de 08:00 a 22:00.
 */
public final class HorarioConsultorio {

  private HorarioConsultorio() {}

  public static LocalTime apertura(DayOfWeek dia) {
    return switch (dia) {
      case SATURDAY -> LocalTime.of(16, 0);
      case SUNDAY -> LocalTime.of(8, 0);
      default -> LocalTime.of(18, 0);
    };
  }

  /** Texto para el mensaje de seguimiento, cuando no hay una fecha concreta. */
  public static String descripcion() {
    return "de lunes a viernes desde las %s, los sábados desde las %s y los domingos de %s a %s"
        .formatted(
            FormatoMensaje.hora(apertura(DayOfWeek.MONDAY)),
            FormatoMensaje.hora(apertura(DayOfWeek.SATURDAY)),
            FormatoMensaje.hora(apertura(DayOfWeek.SUNDAY)),
            FormatoMensaje.hora(LocalTime.of(22, 0)));
  }
}
