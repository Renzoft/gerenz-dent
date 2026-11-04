package pe.gerenzdent.recordatorio.domain;

/**
 * Puerto de envío de mensajes (ADR-001). Hoy la única implementación arma un enlace wa.me que el
 * doctor abre y envía con un toque. Si algún día se usa la API oficial de WhatsApp, se agrega otra
 * implementación sin tocar el dominio ni la app.
 */
public interface ProveedorNotificaciones {

  /** Canal que se registra en cada recordatorio. */
  Canal canal();

  /**
   * Prepara el envío.
   *
   * @param destinoE164 número en formato E.164 (+51987654321)
   * @param mensaje texto ya armado
   * @return enlace para abrir el mensaje, o {@code null} si el envío es automático
   */
  String preparar(String destinoE164, String mensaje);

  enum Canal {
    WHATSAPP_MANUAL,
    WHATSAPP_API
  }
}
