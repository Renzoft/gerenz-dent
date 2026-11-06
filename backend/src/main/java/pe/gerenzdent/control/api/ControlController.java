package pe.gerenzdent.control.api;

import jakarta.validation.Valid;
import java.net.URI;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.control.api.ControlDtos.CambioEstadoRequest;
import pe.gerenzdent.control.api.ControlDtos.CambioEstadoResponse;
import pe.gerenzdent.control.api.ControlDtos.ControlResponse;
import pe.gerenzdent.control.api.ControlDtos.NoVinoRequest;
import pe.gerenzdent.control.api.ControlDtos.NoVinoResponse;
import pe.gerenzdent.control.api.ControlDtos.NuevoControlRequest;
import pe.gerenzdent.control.api.ControlDtos.ReprogramarRequest;
import pe.gerenzdent.control.api.ControlDtos.SugerenciaResponse;
import pe.gerenzdent.control.application.ControlService;
import pe.gerenzdent.control.application.ControlService.CambioDeEstado;
import pe.gerenzdent.control.application.ControlService.NoVino;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.shared.api.UsuarioAutenticado;

@RestController
@RequestMapping("/api/v1")
public class ControlController {

  private final ControlService servicio;

  public ControlController(ControlService servicio) {
    this.servicio = servicio;
  }

  /** Agenda el próximo control de un paciente (HU-11). */
  @PostMapping("/controles")
  public ResponseEntity<ControlResponse> agendar(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody NuevoControlRequest request) {
    Control control = servicio.agendar(UsuarioAutenticado.id(jwt), request.aComando());
    return ResponseEntity.created(URI.create("/api/v1/controles/" + control.getId()))
        .body(ControlResponse.de(control, servicio.hoy()));
  }

  /**
   * Controles abiertos entre dos fechas (por defecto, los próximos 7 días). Con {@code
   * cerrados=true} (calendario) incluye también los que asistieron o no vinieron.
   */
  @GetMapping("/controles")
  public List<ControlResponse> agenda(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
          LocalDate desde,
      @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
          LocalDate hasta,
      @RequestParam(defaultValue = "false") boolean cerrados) {
    LocalDate hoy = servicio.hoy();
    return servicio.agenda(UsuarioAutenticado.id(jwt), desde, hasta, cerrados).stream()
        .map(cp -> ControlResponse.de(cp, hoy))
        .toList();
  }

  /** Controles cuya fecha pasó y el paciente no vino (HU-18). */
  @GetMapping("/controles/vencidos")
  public List<ControlResponse> vencidos(@AuthenticationPrincipal Jwt jwt) {
    LocalDate hoy = servicio.hoy();
    return servicio.vencidos(UsuarioAutenticado.id(jwt)).stream()
        .map(cp -> ControlResponse.de(cp, hoy))
        .toList();
  }

  /** Fecha sugerida según el tratamiento y la edad del paciente (HU-09). */
  @GetMapping("/controles/sugerencia")
  public SugerenciaResponse sugerencia(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam UUID pacienteId,
      @RequestParam UUID tratamientoId) {
    return new SugerenciaResponse(
        servicio.sugerirFecha(UsuarioAutenticado.id(jwt), pacienteId, tratamientoId).orElse(null));
  }

  @GetMapping("/controles/{id}")
  public ControlResponse obtener(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return ControlResponse.de(servicio.obtener(UsuarioAutenticado.id(jwt), id), servicio.hoy());
  }

  /** Confirmado, asistió, no asistió, cancelado (HU-13). */
  @PatchMapping("/controles/{id}/estado")
  public CambioEstadoResponse cambiarEstado(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @Valid @RequestBody CambioEstadoRequest request) {
    CambioDeEstado cambio =
        servicio.cambiarEstado(UsuarioAutenticado.id(jwt), id, request.estado());
    return new CambioEstadoResponse(
        ControlResponse.de(cambio.control(), servicio.hoy()),
        cambio.siguienteFechaSugerida().orElse(null));
  }

  /**
   * El paciente no vino. Con {@code fecha}, se agenda el siguiente control del mismo tratamiento en
   * el mismo paso; sin fecha, queda en "No vinieron" para escribirle.
   */
  @PostMapping("/controles/{id}/no-vino")
  public NoVinoResponse noVino(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @RequestBody(required = false) NoVinoRequest request) {
    LocalDate hoy = servicio.hoy();
    NoVinoRequest datos = request == null ? new NoVinoRequest(null, null) : request;
    NoVino resultado = servicio.noVino(UsuarioAutenticado.id(jwt), id, datos.fecha(), datos.hora());
    return new NoVinoResponse(
        ControlResponse.de(resultado.cerrado(), hoy),
        resultado.siguiente().map(c -> ControlResponse.de(c, hoy)).orElse(null));
  }

  /**
   * Cambia la fecha y vuelve a pendiente (HU-14). En un control que quedó como "no asistió", agenda
   * el siguiente del mismo tratamiento en esa fecha (el "no vino" queda en el historial).
   */
  @PatchMapping("/controles/{id}/fecha")
  public ControlResponse reprogramar(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @Valid @RequestBody ReprogramarRequest request) {
    return ControlResponse.de(
        servicio.reprogramar(
            UsuarioAutenticado.id(jwt),
            id,
            request.fecha(),
            request.hora(),
            Boolean.TRUE.equals(request.confirmado())),
        servicio.hoy());
  }

  /** Historial del paciente, el más reciente primero (HU-05). */
  @GetMapping("/pacientes/{pacienteId}/controles")
  public List<ControlResponse> historial(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID pacienteId) {
    LocalDate hoy = servicio.hoy();
    return servicio.historial(UsuarioAutenticado.id(jwt), pacienteId).stream()
        .map(c -> ControlResponse.de(c, hoy))
        .toList();
  }
}
