package pe.gerenzdent.auth.api;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalTime;
import java.util.UUID;
import pe.gerenzdent.auth.application.Sesion;
import pe.gerenzdent.auth.domain.Usuario;

/** Contratos JSON del módulo de autenticación. */
public final class AuthDtos {

  private AuthDtos() {}

  public record LoginRequest(
      @NotBlank(message = "Ingresa tu correo") @Email(message = "Correo no válido") String email,
      @NotBlank(message = "Ingresa tu contraseña") @Size(max = 200) String password) {

    /** Los espacios alrededor del correo se quitan antes de validar. */
    public LoginRequest {
      email = email == null ? null : email.strip();
    }
  }

  public record RefreshRequest(@NotBlank @Size(max = 200) String refreshToken) {}

  public record UsuarioResponse(UUID id, String nombre, String email, LocalTime horaNotificacion) {
    static UsuarioResponse de(Usuario u) {
      return new UsuarioResponse(u.getId(), u.getNombre(), u.getEmail(), u.getHoraNotificacion());
    }
  }

  public record SesionResponse(
      String accessToken,
      String refreshToken,
      String tipo,
      long expiraEnSegundos,
      UsuarioResponse usuario) {
    static SesionResponse de(Sesion s) {
      return new SesionResponse(
          s.accessToken(),
          s.refreshToken(),
          "Bearer",
          s.duracionAccessToken().toSeconds(),
          UsuarioResponse.de(s.usuario()));
    }
  }
}
