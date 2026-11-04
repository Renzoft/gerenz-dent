package pe.gerenzdent.recordatorio.domain;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

/** Fechas y horas como se escriben en un mensaje de WhatsApp en Perú. */
public final class FormatoMensaje {

  private static final Locale ES_PE = Locale.forLanguageTag("es-PE");
  private static final DateTimeFormatter FECHA =
      DateTimeFormatter.ofPattern("EEEE d 'de' MMMM", ES_PE);

  private FormatoMensaje() {}

  /** 19:30 → "7:30 p. m."; 08:00 → "8:00 a. m."; 12:00 → "12:00 p. m.". */
  public static String hora(LocalTime hora) {
    int h = hora.getHour() % 12 == 0 ? 12 : hora.getHour() % 12;
    String sufijo = hora.getHour() < 12 ? "a. m." : "p. m.";
    return "%d:%02d %s".formatted(h, hora.getMinute(), sufijo);
  }

  /** "martes 11 de noviembre". */
  public static String fecha(LocalDate fecha) {
    return FECHA.format(fecha);
  }

  /** "Juan Pérez" → "Juan". */
  public static String nombreDePila(String nombreCompleto) {
    String limpio = nombreCompleto == null ? "" : nombreCompleto.strip();
    int espacio = limpio.indexOf(' ');
    return espacio < 0 ? limpio : limpio.substring(0, espacio);
  }

  /** "Dr. Marco Munayco" → "el Dr. Marco Munayco"; "Dra. Ana" → "la Dra. Ana". */
  public static String conArticulo(String nombreDoctor) {
    String limpio = nombreDoctor == null ? "" : nombreDoctor.strip();
    String minusculas = limpio.toLowerCase(ES_PE);
    if (minusculas.startsWith("dra.") || minusculas.startsWith("dra ")) {
      return "la " + limpio;
    }
    if (minusculas.startsWith("dr.") || minusculas.startsWith("dr ")) {
      return "el " + limpio;
    }
    return limpio;
  }
}
