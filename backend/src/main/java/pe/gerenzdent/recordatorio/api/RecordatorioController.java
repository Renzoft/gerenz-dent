package pe.gerenzdent.recordatorio.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.control.domain.EstadoControl;
import pe.gerenzdent.recordatorio.application.RecordatorioService;
import pe.gerenzdent.recordatorio.application.RecordatorioService.MensajePreparado;
import pe.gerenzdent.recordatorio.domain.Recordatorio;
import pe.gerenzdent.shared.api.UsuarioAutenticado;

@RestController
@RequestMapping("/api/v1")
public class RecordatorioController {

  private final RecordatorioService servicio;

  public RecordatorioController(RecordatorioService servicio) {
    this.servicio = servicio;
  }

  public record RegistrarEnvioRequest(
      @NotNull(message = "Indica el tipo de recordatorio") Recordatorio.Tipo tipo) {}

  public record RecordatorioResponse(
      UUID id, UUID controlId, Recordatorio.Tipo tipo, Instant enviadoEn) {}

  /** Mensaje armado para un control: el doctor lo abre en WhatsApp con un toque. */
  public record MensajeResponse(
      UUID controlId,
      Recordatorio.Tipo tipo,
      LocalDate fecha,
      LocalTime hora,
      EstadoControl estado,
      long diasAtraso,
      String tratamiento,
      UUID pacienteId,
      String pacienteNombre,
      String pacienteWhatsapp,
      boolean consienteWhatsapp,
      String mensaje,
      String enlace,
      boolean enviado,
      Instant ultimoEnvio) {

    static MensajeResponse de(MensajePreparado m, LocalDate hoy) {
      var c = m.control();
      var p = m.paciente();
      return new MensajeResponse(
          c.getId(),
          m.tipo(),
          c.getFecha(),
          c.getHora(),
          c.getEstado(),
          c.diasDeAtraso(hoy),
          c.getPlan().getTratamiento().getNombre(),
          p.getId(),
          p.getNombre(),
          p.getWhatsapp(),
          p.isConsienteWhatsapp(),
          m.mensaje(),
          m.enlace(),
          m.enviado(),
          m.ultimoEnvio());
    }
  }

  /** Recordatorios de una fecha; por defecto, mañana (HU-15, HU-16). */
  @GetMapping("/recordatorios/pendientes")
  public List<MensajeResponse> pendientes(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
          LocalDate fecha) {
    LocalDate hoy = servicio.hoy();
    return servicio.pendientes(UsuarioAutenticado.id(jwt), fecha).stream()
        .map(m -> MensajeResponse.de(m, hoy))
        .toList();
  }

  /** Seguimientos de controles vencidos (HU-18). */
  @GetMapping("/recordatorios/seguimientos")
  public List<MensajeResponse> seguimientos(@AuthenticationPrincipal Jwt jwt) {
    LocalDate hoy = servicio.hoy();
    return servicio.seguimientos(UsuarioAutenticado.id(jwt)).stream()
        .map(m -> MensajeResponse.de(m, hoy))
        .toList();
  }

  /** El doctor confirma que envió el mensaje (HU-17). */
  @PostMapping("/controles/{controlId}/recordatorios")
  @ResponseStatus(HttpStatus.CREATED)
  public RecordatorioResponse registrar(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID controlId,
      @Valid @RequestBody RegistrarEnvioRequest request) {
    Recordatorio r = servicio.registrarEnvio(UsuarioAutenticado.id(jwt), controlId, request.tipo());
    return new RecordatorioResponse(r.getId(), r.getControlId(), r.getTipo(), r.getEnviadoEn());
  }
}
