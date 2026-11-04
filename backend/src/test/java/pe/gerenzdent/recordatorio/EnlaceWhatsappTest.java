package pe.gerenzdent.recordatorio;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.recordatorio.domain.ProveedorNotificaciones;
import pe.gerenzdent.recordatorio.infrastructure.EnlaceWhatsapp;

class EnlaceWhatsappTest {

  private final EnlaceWhatsapp proveedor = new EnlaceWhatsapp();

  @Test
  void armaElEnlaceWaMeSinElMas() {
    String enlace = proveedor.preparar("+51987654321", "Hola");

    assertThat(enlace).isEqualTo("https://wa.me/51987654321?text=Hola");
    assertThat(proveedor.canal()).isEqualTo(ProveedorNotificaciones.Canal.WHATSAPP_MANUAL);
  }

  @Test
  void codificaEspaciosTildesEmojisYSaltosDeLinea() {
    String mensaje = "Hola Juan 👋, cita de *Brackets* mañana.\n¡Le espero! 🦷";

    String enlace = proveedor.preparar("+51987654321", mensaje);

    assertThat(enlace).doesNotContain("+").doesNotContain(" ").contains("%20");
    String texto = URI.create(enlace).getRawQuery().substring("text=".length());
    assertThat(URLDecoder.decode(texto, StandardCharsets.UTF_8)).isEqualTo(mensaje);
  }
}
