package pe.gerenzdent.recordatorio.infrastructure;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import org.springframework.stereotype.Component;
import pe.gerenzdent.recordatorio.domain.ProveedorNotificaciones;

/**
 * Opción C (ADR-001): arma {@code https://wa.me/<número>?text=<mensaje>}. Al abrirlo en el
 * teléfono, WhatsApp muestra el chat con el mensaje escrito y el doctor solo presiona enviar.
 */
@Component
public class EnlaceWhatsapp implements ProveedorNotificaciones {

  @Override
  public Canal canal() {
    return Canal.WHATSAPP_MANUAL;
  }

  @Override
  public String preparar(String destinoE164, String mensaje) {
    String numero = destinoE164.replace("+", "");
    // URLEncoder codifica los espacios como "+", que wa.me mostraría literal: se usa %20.
    String texto = URLEncoder.encode(mensaje, StandardCharsets.UTF_8).replace("+", "%20");
    return "https://wa.me/" + numero + "?text=" + texto;
  }
}
