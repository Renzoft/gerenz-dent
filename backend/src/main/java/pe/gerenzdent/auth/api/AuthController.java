package pe.gerenzdent.auth.api;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.auth.api.AuthDtos.LoginRequest;
import pe.gerenzdent.auth.api.AuthDtos.RefreshRequest;
import pe.gerenzdent.auth.api.AuthDtos.SesionResponse;
import pe.gerenzdent.auth.api.AuthDtos.UsuarioResponse;
import pe.gerenzdent.auth.application.AuthService;
import pe.gerenzdent.shared.api.UsuarioAutenticado;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

  private final AuthService auth;

  public AuthController(AuthService auth) {
    this.auth = auth;
  }

  @PostMapping("/login")
  public SesionResponse login(@Valid @RequestBody LoginRequest request) {
    return SesionResponse.de(auth.login(request.email(), request.password()));
  }

  @PostMapping("/refresh")
  public SesionResponse refrescar(@Valid @RequestBody RefreshRequest request) {
    return SesionResponse.de(auth.refrescar(request.refreshToken()));
  }

  @PostMapping("/logout")
  public ResponseEntity<Void> logout(@Valid @RequestBody RefreshRequest request) {
    auth.logout(request.refreshToken());
    return ResponseEntity.noContent().build();
  }

  /** Cambia la hora del aviso diario (HU-20). */
  @org.springframework.web.bind.annotation.PatchMapping("/yo")
  public UsuarioResponse preferencias(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AuthDtos.PreferenciasRequest request) {
    return UsuarioResponse.de(
        auth.cambiarHoraNotificacion(UsuarioAutenticado.id(jwt), request.horaNotificacion()));
  }

  @GetMapping("/yo")
  public UsuarioResponse yo(@AuthenticationPrincipal Jwt jwt) {
    return UsuarioResponse.de(auth.usuarioActual(UsuarioAutenticado.id(jwt)));
  }
}
