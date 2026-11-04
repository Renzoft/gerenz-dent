package pe.gerenzdent.auth.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;
import pe.gerenzdent.auth.domain.RefreshToken;
import pe.gerenzdent.auth.domain.Usuario;
import pe.gerenzdent.auth.infrastructure.RefreshTokenRepository;
import pe.gerenzdent.shared.config.PropiedadesSeguridad;

/** Emite access tokens (JWT, 15 min) y refresh tokens opacos (aleatorios, 30 días). */
@Service
public class TokenService {

  static final String EMISOR = "gerenzdent-api";
  private static final int BYTES_REFRESH_TOKEN = 32;

  private final JwtEncoder jwtEncoder;
  private final RefreshTokenRepository refreshTokens;
  private final PropiedadesSeguridad propiedades;
  private final Clock reloj;
  private final SecureRandom aleatorio = new SecureRandom();

  public TokenService(
      JwtEncoder jwtEncoder,
      RefreshTokenRepository refreshTokens,
      PropiedadesSeguridad propiedades,
      Clock reloj) {
    this.jwtEncoder = jwtEncoder;
    this.refreshTokens = refreshTokens;
    this.propiedades = propiedades;
    this.reloj = reloj;
  }

  /** Crea una sesión nueva. Debe llamarse dentro de una transacción. */
  Sesion emitirSesion(Usuario usuario) {
    return new Sesion(
        generarAccessToken(usuario),
        generarRefreshToken(usuario),
        propiedades.duracionAccessToken(),
        usuario);
  }

  private String generarAccessToken(Usuario usuario) {
    Instant ahora = reloj.instant();
    JwtClaimsSet claims =
        JwtClaimsSet.builder()
            .issuer(EMISOR)
            .subject(usuario.getId().toString())
            .issuedAt(ahora)
            .expiresAt(ahora.plus(propiedades.duracionAccessToken()))
            .build();
    JwsHeader cabecera = JwsHeader.with(MacAlgorithm.HS256).build();
    return jwtEncoder.encode(JwtEncoderParameters.from(cabecera, claims)).getTokenValue();
  }

  private String generarRefreshToken(Usuario usuario) {
    byte[] bytes = new byte[BYTES_REFRESH_TOKEN];
    aleatorio.nextBytes(bytes);
    String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    Instant expira = reloj.instant().plus(propiedades.duracionRefreshToken());
    refreshTokens.save(new RefreshToken(usuario.getId(), hash(token), expira));
    return token;
  }

  static String hash(String token) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 no disponible", e);
    }
  }
}
