package pe.gerenzdent.recordatorio.domain;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Textos de los mensajes de WhatsApp (docs/planificacion/02-requisitos.md, épica E). Van de
 * "usted", en primera persona y firmados por el doctor, porque salen de su WhatsApp personal.
 */
public final class PlantillaMensaje {

  private PlantillaMensaje() {}

  /** Datos que necesita un mensaje. {@code hora} es opcional. */
  public record Datos(
      String paciente, String doctor, String tratamiento, LocalDate fecha, LocalTime hora) {}

  /**
   * Recordatorio previo a la cita (normalmente se envía el día anterior). La línea de la cita no
   * lleva punto final: la hora ya termina en "a. m." / "p. m.".
   */
  public static String recordatorio(Datos d, LocalDate hoy) {
    return """
    Hola %s 👋, le saluda %s del consultorio odontológico *GERENZ DENT*.
    Le recordamos su cita de *%s* para %s %s
    Por favor responda *SÍ* para confirmar, o escríbame si necesita cambiar la fecha. \
    ¡Le espero! 🦷\
    """
        .formatted(
            FormatoMensaje.nombreDePila(d.paciente()),
            FormatoMensaje.conArticulo(d.doctor()),
            d.tratamiento(),
            cuando(d.fecha(), hoy),
            horaTexto(d.fecha(), d.hora()));
  }

  /** Seguimiento de un control vencido (el paciente no vino en la fecha acordada). */
  public static String seguimiento(Datos d) {
    return """
    Hola %s 👋, le saluda %s de *GERENZ DENT*.
    Aún tiene pendiente su control de *%s*. Le espero %s.
    Responda a este mensaje para indicarme qué día puede venir. 🦷\
    """
        .formatted(
            FormatoMensaje.nombreDePila(d.paciente()),
            FormatoMensaje.conArticulo(d.doctor()),
            d.tratamiento(),
            HorarioConsultorio.descripcion());
  }

  /** "mañana *martes 11 de noviembre*", "hoy *…*" o "el *…*". */
  static String cuando(LocalDate fecha, LocalDate hoy) {
    String texto = "*" + FormatoMensaje.fecha(fecha) + "*";
    if (fecha.equals(hoy)) {
      return "hoy " + texto;
    }
    if (fecha.equals(hoy.plusDays(1))) {
      return "mañana " + texto;
    }
    return "el " + texto;
  }

  /** Con hora: "a las 7:30 p. m.". Sin hora: "a partir de las 6:00 p. m." según el día (RN-04). */
  static String horaTexto(LocalDate fecha, LocalTime hora) {
    if (hora != null) {
      return "a las " + FormatoMensaje.hora(hora);
    }
    return "a partir de las "
        + FormatoMensaje.hora(HorarioConsultorio.apertura(fecha.getDayOfWeek()));
  }
}
