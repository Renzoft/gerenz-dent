package pe.gerenzdent.tratamiento;

import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import pe.gerenzdent.PruebaIntegracion;

class CatalogoIntegracionTest extends PruebaIntegracion {

  private String autorizacion;

  @BeforeEach
  void preparar() throws Exception {
    autorizacion = autorizacion();
  }

  /** El catálogo es compartido por todas las pruebas: se restaura lo que se cambie aquí. */
  @AfterEach
  void restaurarCatalogo() {
    jdbc.update("DELETE FROM tratamiento WHERE orden > 14");
    jdbc.update(
        "UPDATE tratamiento SET activo = true, precio_base = 70.00"
            + " WHERE nombre IN ('Extracción dental', 'Extracción simple')");
    jdbc.update(
        "UPDATE tratamiento SET nombre = 'Extracción dental' WHERE nombre = 'Extracción simple'");
  }

  private ResultActions enviar(
      org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder req,
      Object... campos)
      throws Exception {
    return mockMvc.perform(
        req.header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json(campos)));
  }

  private String id(String nombre) {
    return jdbc.queryForObject(
        "SELECT id::text FROM tratamiento WHERE nombre = ?", String.class, nombre);
  }

  @Test
  void creaUnTratamientoNuevoAlFinal() throws Exception {
    enviar(
            post("/api/v1/tratamientos"),
            "nombre",
            "  Curación con resina ",
            "tipoPrecio",
            "POR_PIEZA",
            "precioBase",
            90)
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.nombre").value("Curación con resina"))
        .andExpect(jsonPath("$.precioBase").value(90.0))
        .andExpect(jsonPath("$.activo").value(true));

    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/tratamientos")
                .header("Authorization", autorizacion))
        .andExpect(jsonPath("$", hasSize(15)))
        .andExpect(jsonPath("$[14].nombre").value("Curación con resina"));
  }

  @Test
  void noPermiteNombresRepetidos() throws Exception {
    enviar(post("/api/v1/tratamientos"), "nombre", "extracción DENTAL", "tipoPrecio", "FIJO")
        .andExpect(status().isConflict());
  }

  @Test
  void validaLaCuotaMensualYLosRangos() throws Exception {
    enviar(
            post("/api/v1/tratamientos"),
            "nombre",
            "Ortodoncia invisible",
            "tipoPrecio",
            "INICIAL_MAS_MENSUAL",
            "precioBase",
            1000)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.precioMensual").value("Indica la cuota mensual."));
    enviar(
            post("/api/v1/tratamientos"),
            "nombre",
            "Otro",
            "tipoPrecio",
            "FIJO",
            "intervaloControlDias",
            0)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.intervaloControlDias").exists());
  }

  @Test
  void editarElPrecioNoCambiaLosCargosYaGenerados() throws Exception {
    String juan =
        JsonPath.read(
            enviar(post("/api/v1/pacientes"), "nombre", "Juan", "whatsapp", "987654321")
                .andReturn()
                .getResponse()
                .getContentAsString(),
            "$.id");
    String extraccion = id("Extracción dental");
    enviar(
            post("/api/v1/controles"),
            "pacienteId",
            juan,
            "tratamientoId",
            extraccion,
            "fecha",
            java.time.LocalDate.now().plusDays(1).toString())
        .andExpect(status().isCreated());

    enviar(
            put("/api/v1/tratamientos/" + extraccion),
            "nombre",
            "Extracción simple",
            "tipoPrecio",
            "FIJO",
            "precioBase",
            80)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.nombre").value("Extracción simple"))
        .andExpect(jsonPath("$.precioBase").value(80.0));

    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/pacientes/" + juan + "/cuenta")
                .header("Authorization", autorizacion))
        .andExpect(jsonPath("$.deuda").value(70.0));
  }

  @Test
  void unTratamientoInactivoNoSeOfreceAlAgendar() throws Exception {
    String extraccion = id("Extracción dental");

    enviar(patch("/api/v1/tratamientos/" + extraccion + "/activo"), "activo", false)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.activo").value(false));

    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/tratamientos")
                .header("Authorization", autorizacion))
        .andExpect(jsonPath("$", hasSize(13)));
    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/tratamientos?todos=true")
                .header("Authorization", autorizacion))
        .andExpect(jsonPath("$", hasSize(14)))
        .andExpect(jsonPath("$[13].nombre").value("Extracción dental"));
  }
}
