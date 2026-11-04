package pe.gerenzdent.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.auth.domain.Usuario;

class UsuarioTest {

  private static final Instant AHORA = Instant.parse("2026-11-10T23:00:00Z");
  private static final Duration BLOQUEO = Duration.ofMinutes(15);

  private final Usuario usuario = new Usuario(" Doctor@Mail.com ", "hash", "Dr.");

  @Test
  void normalizaElCorreo() {
    assertThat(usuario.getEmail()).isEqualTo("doctor@mail.com");
  }

  @Test
  void seBloqueaAlLlegarAlMaximoDeIntentos() {
    for (int i = 0; i < 4; i++) {
      usuario.registrarIntentoFallido(AHORA, 5, BLOQUEO);
    }
    assertThat(usuario.estaBloqueado(AHORA)).isFalse();

    usuario.registrarIntentoFallido(AHORA, 5, BLOQUEO);

    assertThat(usuario.estaBloqueado(AHORA)).isTrue();
    assertThat(usuario.minutosDeBloqueoRestantes(AHORA)).isEqualTo(15);
  }

  @Test
  void elBloqueoVenceYElContadorEmpiezaDeNuevo() {
    for (int i = 0; i < 5; i++) {
      usuario.registrarIntentoFallido(AHORA, 5, BLOQUEO);
    }
    Instant despues = AHORA.plus(BLOQUEO);

    assertThat(usuario.estaBloqueado(despues)).isFalse();
    usuario.registrarIntentoFallido(despues, 5, BLOQUEO);
    assertThat(usuario.estaBloqueado(despues)).isFalse();
    assertThat(usuario.getIntentosFallidos()).isEqualTo(1);
  }

  @Test
  void minutosRestantesSeRedondeanHaciaArriba() {
    for (int i = 0; i < 5; i++) {
      usuario.registrarIntentoFallido(AHORA, 5, BLOQUEO);
    }
    assertThat(usuario.minutosDeBloqueoRestantes(AHORA.plusSeconds(14 * 60 + 30))).isEqualTo(1);
  }

  @Test
  void loginExitosoReiniciaElContador() {
    usuario.registrarIntentoFallido(AHORA, 5, BLOQUEO);
    usuario.registrarLoginExitoso();
    assertThat(usuario.getIntentosFallidos()).isZero();
  }
}
