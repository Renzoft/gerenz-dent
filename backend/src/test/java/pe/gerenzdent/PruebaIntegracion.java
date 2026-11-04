package pe.gerenzdent;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import pe.gerenzdent.auth.domain.Usuario;
import pe.gerenzdent.auth.infrastructure.UsuarioRepository;

/**
 * Base de las pruebas de integración: API completa + PostgreSQL real (Testcontainers). Todas las
 * clases comparten el mismo contexto de Spring y el mismo contenedor; la BD se limpia antes de cada
 * prueba.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Import(TestcontainersConfiguration.class)
public abstract class PruebaIntegracion {

  protected static final String EMAIL = "doctor@gerenzdent.test";
  protected static final String PASSWORD = "clave-de-prueba-123";

  @Autowired protected MockMvc mockMvc;
  @Autowired protected JdbcTemplate jdbc;
  @Autowired protected UsuarioRepository usuarios;
  @Autowired protected PasswordEncoder passwordEncoder;

  @BeforeEach
  void limpiarBaseDeDatos() {
    jdbc.execute("TRUNCATE control, plan_tratamiento, paciente, refresh_token, usuario CASCADE");
  }

  protected Usuario crearUsuario(String email, String password) {
    return usuarios.save(new Usuario(email, passwordEncoder.encode(password), "Dr. Prueba"));
  }

  /** Respuesta JSON completa del login. */
  protected String login(String email, String password) throws Exception {
    return mockMvc
        .perform(
            post("/api/v1/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("email", email, "password", password)))
        .andExpect(status().isOk())
        .andReturn()
        .getResponse()
        .getContentAsString();
  }

  /** Crea el usuario por defecto, inicia sesión y devuelve el header "Bearer ...". */
  protected String autorizacion() throws Exception {
    crearUsuario(EMAIL, PASSWORD);
    return "Bearer " + JsonPath.read(login(EMAIL, PASSWORD), "$.accessToken");
  }

  /** Construye un JSON plano de pares clave/valor (los valores se escapan). */
  protected static String json(Object... clavesYValores) {
    StringBuilder sb = new StringBuilder("{");
    for (int i = 0; i < clavesYValores.length; i += 2) {
      if (i > 0) {
        sb.append(',');
      }
      sb.append('"').append(clavesYValores[i]).append("\":");
      Object valor = clavesYValores[i + 1];
      if (valor == null || valor instanceof Number || valor instanceof Boolean) {
        sb.append(valor);
      } else {
        sb.append('"')
            .append(valor.toString().replace("\\", "\\\\").replace("\"", "\\\""))
            .append('"');
      }
    }
    return sb.append('}').toString();
  }
}
