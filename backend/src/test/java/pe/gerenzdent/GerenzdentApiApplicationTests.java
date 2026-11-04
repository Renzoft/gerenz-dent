package pe.gerenzdent;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;

class GerenzdentApiApplicationTests extends PruebaIntegracion {

  @Test
  void healthRespondeUpSinAutenticacion() throws Exception {
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
  void flywayAplicoTodasLasMigraciones() {
    Integer extensiones =
        jdbc.queryForObject(
            "SELECT count(*) FROM pg_extension WHERE extname = 'pg_trgm'", Integer.class);
    Integer tablas =
        jdbc.queryForObject(
            "SELECT count(*) FROM information_schema.tables"
                + " WHERE table_name IN ('usuario', 'refresh_token', 'paciente', 'tratamiento', 'plan_tratamiento', 'control')",
            Integer.class);
    assertThat(extensiones).isEqualTo(1);
    assertThat(tablas).isEqualTo(6);
  }

  @Test
  void endpointsSensiblesDeActuatorNoSonAccesibles() throws Exception {
    mockMvc.perform(get("/actuator/env")).andExpect(status().isUnauthorized());
  }

  @Test
  void rutasDeLaApiExigenAutenticacionConFormatoProblemDetails() throws Exception {
    mockMvc
        .perform(get("/api/v1/pacientes"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.status").value(401))
        .andExpect(jsonPath("$.title").value("No autenticado"));
  }
}
