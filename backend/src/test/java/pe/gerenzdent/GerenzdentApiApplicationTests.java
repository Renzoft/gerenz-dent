package pe.gerenzdent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
@AutoConfigureMockMvc
class GerenzdentApiApplicationTests {

  @Autowired MockMvc mockMvc;
  @Autowired JdbcTemplate jdbc;

  @Test
  void healthRespondeUp() throws Exception {
    mockMvc
        .perform(get("/actuator/health"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("UP"));
  }

  @Test
  void healthNoExponeDetalles() throws Exception {
    mockMvc.perform(get("/actuator/health")).andExpect(jsonPath("$.components").doesNotExist());
  }

  @Test
  void flywayAplicoLaMigracionInicial() {
    Integer extensiones =
        jdbc.queryForObject(
            "SELECT count(*) FROM pg_extension WHERE extname = 'pg_trgm'", Integer.class);
    assertThat(extensiones).isEqualTo(1);
  }

  @Test
  void endpointsDeActuatorSensiblesNoEstanExpuestos() throws Exception {
    mockMvc.perform(get("/actuator/env")).andExpect(status().isNotFound());
  }
}
