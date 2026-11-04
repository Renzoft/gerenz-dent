package pe.gerenzdent.shared.api;

import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/** Obtiene el id del usuario desde el access token (claim "sub"). */
public final class UsuarioAutenticado {

  private UsuarioAutenticado() {}

  public static UUID id(Jwt jwt) {
    return UUID.fromString(jwt.getSubject());
  }
}
