package pe.gerenzdent.shared.config;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/** Parámetros de autenticación (app.seguridad.*). La API no arranca si son inválidos. */
@Validated
@ConfigurationProperties("app.seguridad")
public record PropiedadesSeguridad(
    @NotBlank(message = "Define la variable de entorno JWT_SECRET")
        @Size(min = 32, message = "JWT_SECRET debe tener al menos 32 caracteres")
        String jwtSecreto,
    @Positive int accessTokenMinutos,
    @Positive int refreshTokenDias,
    @Min(1) int maxIntentosLogin,
    @Positive int bloqueoMinutos) {

  public Duration duracionAccessToken() {
    return Duration.ofMinutes(accessTokenMinutos);
  }

  public Duration duracionRefreshToken() {
    return Duration.ofDays(refreshTokenDias);
  }

  public Duration duracionBloqueo() {
    return Duration.ofMinutes(bloqueoMinutos);
  }
}
