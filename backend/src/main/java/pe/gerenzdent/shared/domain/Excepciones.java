package pe.gerenzdent.shared.domain;

import java.util.Map;

/**
 * Errores de negocio. El dominio no conoce HTTP: {@code ManejadorErrores} traduce cada tipo a su
 * código de estado y formato RFC 9457.
 */
public final class Excepciones {

  private Excepciones() {}

  /** Base de los errores esperados del negocio (no son fallos del sistema). */
  public abstract static class ErrorDeNegocio extends RuntimeException {
    protected ErrorDeNegocio(String mensaje) {
      super(mensaje);
    }
  }

  /** 404. También se usa cuando el recurso existe pero pertenece a otro usuario. */
  public static class RecursoNoEncontrado extends ErrorDeNegocio {
    public RecursoNoEncontrado(String mensaje) {
      super(mensaje);
    }
  }

  /** 400 con el campo inválido. */
  public static class DatoInvalido extends ErrorDeNegocio {
    private final String campo;

    public DatoInvalido(String campo, String mensaje) {
      super(mensaje);
      this.campo = campo;
    }

    public String campo() {
      return campo;
    }
  }

  /** 409. {@code datos} viaja en la respuesta (p. ej. el id del paciente que ya existe). */
  public static class Conflicto extends ErrorDeNegocio {
    private final transient Map<String, Object> datos;

    public Conflicto(String mensaje, Map<String, Object> datos) {
      super(mensaje);
      this.datos = Map.copyOf(datos);
    }

    public Map<String, Object> datos() {
      return datos;
    }
  }

  /** 401. Mismo mensaje para correo inexistente o contraseña errada (no revela cuál falló). */
  public static class CredencialesInvalidas extends ErrorDeNegocio {
    public CredencialesInvalidas() {
      super("Correo o contraseña incorrectos.");
    }
  }

  /** 401. Refresh token inexistente, vencido o revocado. */
  public static class SesionInvalida extends ErrorDeNegocio {
    public SesionInvalida() {
      super("La sesión expiró. Inicia sesión nuevamente.");
    }
  }

  /** 429. Demasiados intentos de login fallidos seguidos. */
  public static class LoginBloqueado extends ErrorDeNegocio {
    private final long minutosRestantes;

    public LoginBloqueado(long minutosRestantes) {
      super(
          "Demasiados intentos fallidos. Inténtalo de nuevo en %d minuto(s)."
              .formatted(minutosRestantes));
      this.minutosRestantes = minutosRestantes;
    }

    public long minutosRestantes() {
      return minutosRestantes;
    }
  }
}
