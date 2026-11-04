package pe.gerenzdent.paciente.api;

import jakarta.validation.Valid;
import java.net.URI;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.paciente.api.PacienteDtos.PacienteRequest;
import pe.gerenzdent.paciente.api.PacienteDtos.PacienteResponse;
import pe.gerenzdent.paciente.application.PacienteService;
import pe.gerenzdent.paciente.domain.Paciente;
import pe.gerenzdent.shared.api.PaginaResponse;
import pe.gerenzdent.shared.api.UsuarioAutenticado;

@RestController
@RequestMapping("/api/v1/pacientes")
public class PacienteController {

  private final PacienteService servicio;

  public PacienteController(PacienteService servicio) {
    this.servicio = servicio;
  }

  /** Lista o busca: {@code ?q=perez&archivados=false&pagina=0&tamano=20}. */
  @GetMapping
  public PaginaResponse<PacienteResponse> listar(
      @AuthenticationPrincipal Jwt jwt,
      @RequestParam(required = false) String q,
      @RequestParam(defaultValue = "false") boolean archivados,
      @RequestParam(defaultValue = "0") int pagina,
      @RequestParam(defaultValue = "20") int tamano) {
    return PaginaResponse.de(
        servicio.buscar(UsuarioAutenticado.id(jwt), q, archivados, pagina, tamano),
        PacienteResponse::de);
  }

  @GetMapping("/{id}")
  public PacienteResponse obtener(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return PacienteResponse.de(servicio.obtener(UsuarioAutenticado.id(jwt), id));
  }

  @PostMapping
  public ResponseEntity<PacienteResponse> crear(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PacienteRequest request) {
    Paciente creado = servicio.crear(UsuarioAutenticado.id(jwt), request.aDatos());
    return ResponseEntity.created(URI.create("/api/v1/pacientes/" + creado.getId()))
        .body(PacienteResponse.de(creado));
  }

  @PutMapping("/{id}")
  public PacienteResponse actualizar(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @Valid @RequestBody PacienteRequest request) {
    return PacienteResponse.de(
        servicio.actualizar(UsuarioAutenticado.id(jwt), id, request.aDatos()));
  }

  @PatchMapping("/{id}/archivar")
  public PacienteResponse archivar(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return PacienteResponse.de(servicio.archivar(UsuarioAutenticado.id(jwt), id));
  }

  @PatchMapping("/{id}/desarchivar")
  public PacienteResponse desarchivar(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return PacienteResponse.de(servicio.desarchivar(UsuarioAutenticado.id(jwt), id));
  }
}
