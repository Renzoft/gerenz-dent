package pe.gerenzdent.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import pe.gerenzdent.PruebaIntegracion;

class AuthIntegracionTest extends PruebaIntegracion {

  private ResultActions intentarLogin(String email, String password) throws Exception {
    return mockMvc.perform(
        post("/api/v1/auth/login")
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("email", email, "password", password)));
  }

  private ResultActions refrescar(String refreshToken) throws Exception {
    return mockMvc.perform(
        post("/api/v1/auth/refresh")
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("refreshToken", refreshToken)));
  }

  @Test
  void loginCorrectoDevuelveTokensYUsuario() throws Exception {
    crearUsuario(EMAIL, PASSWORD);

    intentarLogin(EMAIL, PASSWORD)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.accessToken").isNotEmpty())
        .andExpect(jsonPath("$.refreshToken").isNotEmpty())
        .andExpect(jsonPath("$.tipo").value("Bearer"))
        .andExpect(jsonPath("$.expiraEnSegundos").value(900))
        .andExpect(jsonPath("$.usuario.email").value(EMAIL))
        .andExpect(
            jsonPath("$.usuario.horaNotificacion").value(org.hamcrest.Matchers.startsWith("16:30")))
        .andExpect(jsonPath("$.usuario.passwordHash").doesNotExist());
  }

  @Test
  void elCorreoNoDistingueMayusculasNiEspacios() throws Exception {
    crearUsuario(EMAIL, PASSWORD);

    intentarLogin("  Doctor@GerenzDent.TEST ", PASSWORD).andExpect(status().isOk());
  }

  @Test
  void contrasenaIncorrectaYCorreoInexistenteDanElMismoError() throws Exception {
    crearUsuario(EMAIL, PASSWORD);

    String errada =
        intentarLogin(EMAIL, "otra-clave")
            .andExpect(status().isUnauthorized())
            .andReturn()
            .getResponse()
            .getContentAsString();
    String inexistente =
        intentarLogin("nadie@gerenzdent.test", "otra-clave")
            .andExpect(status().isUnauthorized())
            .andReturn()
            .getResponse()
            .getContentAsString();

    assertThat(JsonPath.<String>read(errada, "$.detail"))
        .isEqualTo(JsonPath.<String>read(inexistente, "$.detail"))
        .isEqualTo("Correo o contraseña incorrectos.");
  }

  @Test
  void cincoIntentosFallidosBloqueanElLoginAunqueLuegoLaClaveSeaCorrecta() throws Exception {
    crearUsuario(EMAIL, PASSWORD);

    for (int i = 0; i < 4; i++) {
      intentarLogin(EMAIL, "errada").andExpect(status().isUnauthorized());
    }
    intentarLogin(EMAIL, "errada")
        .andExpect(status().isTooManyRequests())
        .andExpect(header().string("Retry-After", "900"));

    intentarLogin(EMAIL, PASSWORD)
        .andExpect(status().isTooManyRequests())
        .andExpect(jsonPath("$.detail").value(org.hamcrest.Matchers.containsString("15 minuto")));
  }

  @Test
  void unLoginCorrectoReiniciaElContadorDeIntentos() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    for (int i = 0; i < 4; i++) {
      intentarLogin(EMAIL, "errada").andExpect(status().isUnauthorized());
    }
    intentarLogin(EMAIL, PASSWORD).andExpect(status().isOk());

    intentarLogin(EMAIL, "errada").andExpect(status().isUnauthorized());
  }

  @Test
  void validaElCuerpoDelLogin() throws Exception {
    intentarLogin("no-es-correo", "")
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.email").value("Correo no válido"))
        .andExpect(jsonPath("$.errores.password").value("Ingresa tu contraseña"));
  }

  @Test
  void elAccessTokenPermiteConsultarElUsuarioActual() throws Exception {
    String autorizacion = autorizacion();

    mockMvc
        .perform(get("/api/v1/auth/yo").header("Authorization", autorizacion))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.email").value(EMAIL));
  }

  @Test
  void unTokenAlteradoEsRechazado() throws Exception {
    String autorizacion = autorizacion();

    mockMvc
        .perform(get("/api/v1/auth/yo").header("Authorization", autorizacion + "x"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void refreshRotaElTokenYElAnteriorDejaDeServir() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    String original = JsonPath.read(login(EMAIL, PASSWORD), "$.refreshToken");

    String respuesta =
        refrescar(original)
            .andExpect(status().isOk())
            .andReturn()
            .getResponse()
            .getContentAsString();
    String nuevo = JsonPath.read(respuesta, "$.refreshToken");

    assertThat(nuevo).isNotEqualTo(original);
    refrescar(original).andExpect(status().isUnauthorized());
  }

  @Test
  void reutilizarUnRefreshTokenRevocadoCierraTodasLasSesiones() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    String original = JsonPath.read(login(EMAIL, PASSWORD), "$.refreshToken");
    String nuevo =
        JsonPath.read(
            refrescar(original).andReturn().getResponse().getContentAsString(), "$.refreshToken");

    refrescar(original).andExpect(status().isUnauthorized()); // posible robo
    refrescar(nuevo).andExpect(status().isUnauthorized()); // la sesión legítima también se cerró
  }

  @Test
  void logoutRevocaElRefreshTokenYEsIdempotente() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    String refresh = JsonPath.read(login(EMAIL, PASSWORD), "$.refreshToken");

    for (int i = 0; i < 2; i++) {
      mockMvc
          .perform(
              post("/api/v1/auth/logout")
                  .contentType(MediaType.APPLICATION_JSON)
                  .content(json("refreshToken", refresh)))
          .andExpect(status().isNoContent());
    }
    refrescar(refresh).andExpect(status().isUnauthorized());
  }

  @Test
  void refreshTokenInexistenteEsRechazado() throws Exception {
    refrescar("token-inventado").andExpect(status().isUnauthorized());
  }

  @Test
  void enLaBaseDeDatosSoloSeGuardaElHashDelRefreshToken() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    String refresh = JsonPath.read(login(EMAIL, PASSWORD), "$.refreshToken");

    Integer enClaro =
        jdbc.queryForObject(
            "SELECT count(*) FROM refresh_token WHERE token_hash = ?", Integer.class, refresh);
    assertThat(enClaro).isZero();
  }
}
