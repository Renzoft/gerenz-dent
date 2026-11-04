package pe.gerenzdent.auth.infrastructure;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.auth.domain.Usuario;

/**
 * La app tiene un solo usuario y no hay registro público. En el primer arranque, si la tabla está
 * vacía, se crea con ADMIN_EMAIL / ADMIN_PASSWORD (variables de entorno, nunca en el repositorio).
 */
@Component
public class UsuarioInicial implements ApplicationRunner {

  private static final Logger log = LoggerFactory.getLogger(UsuarioInicial.class);
  static final int LONGITUD_MINIMA_PASSWORD = 10;

  private final UsuarioRepository usuarios;
  private final PasswordEncoder passwordEncoder;
  private final Datos datos;

  public UsuarioInicial(UsuarioRepository usuarios, PasswordEncoder passwordEncoder, Datos datos) {
    this.usuarios = usuarios;
    this.passwordEncoder = passwordEncoder;
    this.datos = datos;
  }

  @ConfigurationProperties("app.admin-inicial")
  public record Datos(String email, String password, String nombre) {}

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    if (usuarios.count() > 0) {
      return;
    }
    if (estaVacio(datos.email()) || estaVacio(datos.password())) {
      log.warn(
          "No hay usuarios y faltan ADMIN_EMAIL / ADMIN_PASSWORD: nadie podrá iniciar sesión.");
      return;
    }
    if (datos.password().length() < LONGITUD_MINIMA_PASSWORD) {
      log.error(
          "ADMIN_PASSWORD debe tener al menos {} caracteres; no se creó el usuario.",
          LONGITUD_MINIMA_PASSWORD);
      return;
    }
    String nombre = estaVacio(datos.nombre()) ? "Doctor" : datos.nombre().strip();
    usuarios.save(new Usuario(datos.email(), passwordEncoder.encode(datos.password()), nombre));
    log.info("Usuario inicial creado.");
  }

  private static boolean estaVacio(String valor) {
    return valor == null || valor.isBlank();
  }
}
