package pe.gerenzdent.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import pe.gerenzdent.PruebaIntegracion;
import pe.gerenzdent.auth.infrastructure.UsuarioInicial;

class UsuarioInicialTest extends PruebaIntegracion {

  private void ejecutar(String email, String password) {
    new UsuarioInicial(
            usuarios, passwordEncoder, new UsuarioInicial.Datos(email, password, "Dr. Marco"))
        .run(null);
  }

  @Test
  void creaElUsuarioSiNoHayNinguno() throws Exception {
    ejecutar("Doctor@GerenzDent.test", "una-clave-larga");

    assertThat(usuarios.count()).isEqualTo(1);
    login("doctor@gerenzdent.test", "una-clave-larga");
  }

  @Test
  void noHaceNadaSiYaExisteUnUsuario() {
    crearUsuario(EMAIL, PASSWORD);

    ejecutar("otro@gerenzdent.test", "una-clave-larga");

    assertThat(usuarios.count()).isEqualTo(1);
  }

  @Test
  void noCreaElUsuarioSinCredencialesOConClaveCorta() {
    ejecutar("", "una-clave-larga");
    ejecutar("doctor@gerenzdent.test", "corta");

    assertThat(usuarios.count()).isZero();
  }
}
