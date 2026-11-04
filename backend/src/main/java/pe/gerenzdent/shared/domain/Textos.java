package pe.gerenzdent.shared.domain;

import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;

/** Utilidades de normalización de texto ingresado por el usuario. */
public final class Textos {

  private static final Pattern ESPACIOS = Pattern.compile("\\s+");
  private static final Pattern MARCAS_DIACRITICAS = Pattern.compile("\\p{M}+");

  private Textos() {}

  /** Quita espacios al inicio/fin y deja un solo espacio entre palabras. {@code null} → null. */
  public static String limpiar(String texto) {
    if (texto == null) {
      return null;
    }
    return ESPACIOS.matcher(texto.strip()).replaceAll(" ");
  }

  /** Como {@link #limpiar}, pero un texto vacío se vuelve {@code null} (campos opcionales). */
  public static String limpiarOpcional(String texto) {
    String limpio = limpiar(texto);
    return limpio == null || limpio.isEmpty() ? null : limpio;
  }

  /** Minúsculas y sin tildes: "José Pérez" → "jose perez". La ñ se conserva como "n". */
  public static String paraBusqueda(String texto) {
    String limpio = limpiar(texto);
    if (limpio == null) {
      return "";
    }
    String sinTildes =
        MARCAS_DIACRITICAS
            .matcher(Normalizer.normalize(limpio, Normalizer.Form.NFD))
            .replaceAll("");
    return sinTildes.toLowerCase(Locale.ROOT);
  }
}
