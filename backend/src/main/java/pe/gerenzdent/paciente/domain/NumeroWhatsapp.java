package pe.gerenzdent.paciente.domain;

import java.util.regex.Pattern;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

/**
 * Normaliza un número de WhatsApp al formato E.164 (+51987654321), que es el que necesita el enlace
 * wa.me. Por defecto asume Perú (+51).
 *
 * <p>Acepta: "987654321", "987 654 321", "987-654-321", "51987654321", "+51 987 654 321",
 * "0051987654321" y números de otros países con "+" o "00" (p. ej. "+1 415 555 2671").
 */
public final class NumeroWhatsapp {

  static final String CODIGO_PERU = "51";
  private static final Pattern SEPARADORES = Pattern.compile("[\\s\\-().]");
  private static final Pattern SOLO_DIGITOS = Pattern.compile("\\d+");
  private static final Pattern CELULAR_PERU = Pattern.compile("9\\d{8}");

  private NumeroWhatsapp() {}

  public static String normalizar(String entrada) {
    if (entrada == null || entrada.isBlank()) {
      throw invalido("Ingresa el número de WhatsApp.");
    }
    String texto = SEPARADORES.matcher(entrada.strip()).replaceAll("");

    boolean internacional = false;
    if (texto.startsWith("+")) {
      texto = texto.substring(1);
      internacional = true;
    } else if (texto.startsWith("00")) {
      texto = texto.substring(2);
      internacional = true;
    }

    if (!SOLO_DIGITOS.matcher(texto).matches()) {
      throw invalido("El número solo puede tener dígitos, espacios o guiones.");
    }

    if (!internacional) {
      if (CELULAR_PERU.matcher(texto).matches()) {
        return "+" + CODIGO_PERU + texto;
      }
      if (texto.length() == 11 && texto.startsWith(CODIGO_PERU + "9")) {
        return "+" + texto;
      }
      throw invalido("Escribe un celular de 9 dígitos que empiece con 9, o el número con +código.");
    }

    if (texto.startsWith(CODIGO_PERU) && !CELULAR_PERU.matcher(texto.substring(2)).matches()) {
      throw invalido("Los celulares de Perú tienen 9 dígitos y empiezan con 9.");
    }
    // E.164: código de país (sin 0 inicial) + número, entre 8 y 15 dígitos en total.
    if (texto.startsWith("0") || texto.length() < 8 || texto.length() > 15) {
      throw invalido("El número internacional no es válido.");
    }
    return "+" + texto;
  }

  private static DatoInvalido invalido(String mensaje) {
    return new DatoInvalido("whatsapp", mensaje);
  }
}
