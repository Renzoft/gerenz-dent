package pe.gerenzdent.auth.application;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.auth.domain.RefreshToken;
import pe.gerenzdent.auth.domain.Usuario;
import pe.gerenzdent.auth.infrastructure.RefreshTokenRepository;
import pe.gerenzdent.auth.infrastructure.UsuarioRepository;
import pe.gerenzdent.shared.config.PropiedadesSeguridad;
import pe.gerenzdent.shared.domain.Excepciones.CredencialesInvalidas;
import pe.gerenzdent.shared.domain.Excepciones.LoginBloqueado;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.shared.domain.Excepciones.SesionInvalida;

/** Casos de uso de autenticación (HU-01). */
@Service
public class AuthService {

  private static final Logger log = LoggerFactory.getLogger(AuthService.class);

  private final UsuarioRepository usuarios;
  private final RefreshTokenRepository refreshTokens;
  private final TokenService tokens;
  private final PasswordEncoder passwordEncoder;
  private final PropiedadesSeguridad propiedades;
  private final Clock reloj;

  /**
   * Hash de una contraseña cualquiera: se compara contra él cuando el correo no existe, para que la
   * respuesta tarde lo mismo y no revele qué correos están registrados.
   */
  private final String hashSenuelo;

  public AuthService(
      UsuarioRepository usuarios,
      RefreshTokenRepository refreshTokens,
      TokenService tokens,
      PasswordEncoder passwordEncoder,
      PropiedadesSeguridad propiedades,
      Clock reloj) {
    this.usuarios = usuarios;
    this.refreshTokens = refreshTokens;
    this.tokens = tokens;
    this.passwordEncoder = passwordEncoder;
    this.propiedades = propiedades;
    this.reloj = reloj;
    this.hashSenuelo = passwordEncoder.encode(UUID.randomUUID().toString());
  }

  /** Los intentos fallidos deben guardarse aunque se lance la excepción. */
  @Transactional(noRollbackFor = {CredencialesInvalidas.class, LoginBloqueado.class})
  public Sesion login(String email, String password) {
    Instant ahora = reloj.instant();
    Optional<Usuario> encontrado = usuarios.findByEmail(Usuario.normalizarEmail(email));

    if (encontrado.isEmpty()) {
      passwordEncoder.matches(password, hashSenuelo);
      throw new CredencialesInvalidas();
    }

    Usuario usuario = encontrado.get();
    if (usuario.estaBloqueado(ahora)) {
      throw new LoginBloqueado(usuario.minutosDeBloqueoRestantes(ahora));
    }

    if (!passwordEncoder.matches(password, usuario.getPasswordHash())) {
      usuario.registrarIntentoFallido(
          ahora, propiedades.maxIntentosLogin(), propiedades.duracionBloqueo());
      if (usuario.estaBloqueado(ahora)) {
        log.warn("Login bloqueado por intentos fallidos (usuario {})", usuario.getId());
        throw new LoginBloqueado(usuario.minutosDeBloqueoRestantes(ahora));
      }
      throw new CredencialesInvalidas();
    }

    usuario.registrarLoginExitoso();
    return tokens.emitirSesion(usuario);
  }

  /**
   * Rotación: el refresh token usado se revoca y se entrega uno nuevo. Si llega un token ya
   * revocado (posible robo), se cierran todas las sesiones del usuario.
   */
  @Transactional(noRollbackFor = SesionInvalida.class)
  public Sesion refrescar(String refreshToken) {
    Instant ahora = reloj.instant();
    RefreshToken guardado =
        refreshTokens
            .findByTokenHash(TokenService.hash(refreshToken))
            .orElseThrow(SesionInvalida::new);

    if (guardado.estaRevocado()) {
      int cerradas = refreshTokens.revocarTodos(guardado.getUsuarioId(), ahora);
      log.warn(
          "Reutilización de refresh token detectada (usuario {}): {} sesión(es) cerradas",
          guardado.getUsuarioId(),
          cerradas);
      throw new SesionInvalida();
    }
    if (guardado.estaVencido(ahora)) {
      throw new SesionInvalida();
    }

    guardado.revocar(ahora);
    Usuario usuario = usuarios.findById(guardado.getUsuarioId()).orElseThrow(SesionInvalida::new);
    return tokens.emitirSesion(usuario);
  }

  /** Idempotente: cerrar una sesión inexistente o ya cerrada no es un error. */
  @Transactional
  public void logout(String refreshToken) {
    refreshTokens
        .findByTokenHash(TokenService.hash(refreshToken))
        .ifPresent(t -> t.revocar(reloj.instant()));
  }

  @Transactional
  public Usuario cambiarHoraNotificacion(UUID usuarioId, java.time.LocalTime hora) {
    Usuario usuario = usuarioActual(usuarioId);
    usuario.cambiarHoraNotificacion(hora);
    return usuarios.saveAndFlush(usuario);
  }

  @Transactional(readOnly = true)
  public Usuario usuarioActual(UUID usuarioId) {
    return usuarios
        .findById(usuarioId)
        .orElseThrow(() -> new RecursoNoEncontrado("Usuario no encontrado."));
  }
}
