package pe.gerenzdent.recordatorio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import pe.gerenzdent.PruebaIntegracion;
import pe.gerenzdent.shared.config.Calendario;

class RecordatorioIntegracionTest extends PruebaIntegracion {

  @Autowired Calendario calendario;

  private String autorizacion;
  private LocalDate hoy;
  private String brackets;

  @BeforeEach
  void preparar() throws Exception {
    autorizacion = autorizacion();
    hoy = calendario.hoy();
    brackets =
        jdbc.queryForObject(
            "SELECT id::text FROM tratamiento WHERE nombre = 'Brackets (ortodoncia)'",
            String.class);
  }

  private String crearPaciente(String nombre, String whatsapp, boolean consiente) throws Exception {
    String r =
        mockMvc
            .perform(
                post("/api/v1/pacientes")
                    .header("Authorization", autorizacion)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        json(
                            "nombre",
                            nombre,
                            "whatsapp",
                            whatsapp,
                            "consienteWhatsapp",
                            consiente)))
            .andReturn()
            .getResponse()
            .getContentAsString();
    return JsonPath.read(r, "$.id");
  }

  private String agendar(String pacienteId, LocalDate fecha, String hora) throws Exception {
    String r =
        mockMvc
            .perform(
                post("/api/v1/controles")
                    .header("Authorization", autorizacion)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(
                        json(
                            "pacienteId",
                            pacienteId,
                            "tratamientoId",
                            brackets,
                            "fecha",
                            fecha.toString(),
                            "hora",
                            hora)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    return JsonPath.read(r, "$.id");
  }

  private ResultActions get(String ruta) throws Exception {
    return mockMvc.perform(MockMvcRequestBuilders.get(ruta).header("Authorization", autorizacion));
  }

  private ResultActions registrar(String controlId, String tipo) throws Exception {
    return mockMvc.perform(
        post("/api/v1/controles/" + controlId + "/recordatorios")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("tipo", tipo)));
  }

  @Test
  void losPendientesDeMananaTraenElMensajeYElEnlace() throws Exception {
    String juan = crearPaciente("Juan Pérez", "987654321", true);
    agendar(juan, hoy.plusDays(1), "19:30");
    agendar(crearPaciente("Otro día", "922222222", true), hoy.plusDays(3), null);

    get("/api/v1/recordatorios/pendientes")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].pacienteNombre").value("Juan Pérez"))
        .andExpect(jsonPath("$[0].tipo").value("PREVIO"))
        .andExpect(jsonPath("$[0].mensaje", startsWith("Hola Juan 👋, le saluda el Dr. Prueba")))
        .andExpect(jsonPath("$[0].mensaje", containsString("para mañana")))
        .andExpect(jsonPath("$[0].mensaje", containsString("a las 7:30 p. m.")))
        .andExpect(
            jsonPath("$[0].enlace", startsWith("https://wa.me/51987654321?text=Hola%20Juan")))
        .andExpect(jsonPath("$[0].enviado").value(false));
  }

  @Test
  void sinConsentimientoNoHayEnlace() throws Exception {
    String ana = crearPaciente("Ana", "912345678", false);
    agendar(ana, hoy.plusDays(1), null);

    get("/api/v1/recordatorios/pendientes")
        .andExpect(jsonPath("$[0].consienteWhatsapp").value(false))
        .andExpect(jsonPath("$[0].enlace").doesNotExist())
        .andExpect(jsonPath("$[0].mensaje").exists());
  }

  @Test
  void registrarElEnvioPasaElControlARecordado() throws Exception {
    String juan = crearPaciente("Juan", "987654321", true);
    String control = agendar(juan, hoy.plusDays(1), null);

    registrar(control, "PREVIO")
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.tipo").value("PREVIO"))
        .andExpect(jsonPath("$.enviadoEn").exists());

    get("/api/v1/recordatorios/pendientes")
        .andExpect(jsonPath("$[0].enviado").value(true))
        .andExpect(jsonPath("$[0].estado").value("RECORDADO"));
    String canal = jdbc.queryForObject("SELECT canal FROM recordatorio", String.class);
    assertThat(canal).isEqualTo("WHATSAPP_MANUAL");
  }

  @Test
  void seguimientosDeVencidosConSuMensaje() throws Exception {
    String juan = crearPaciente("Juan", "987654321", true);
    String control = agendar(juan, hoy, null);
    jdbc.update("UPDATE control SET fecha = ? WHERE id::text = ?", hoy.minusDays(3), control);

    get("/api/v1/recordatorios/seguimientos")
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].tipo").value("SEGUIMIENTO"))
        .andExpect(jsonPath("$[0].diasAtraso").value(3))
        .andExpect(jsonPath("$[0].mensaje", containsString("Aún tiene pendiente su control")))
        .andExpect(jsonPath("$[0].enviado").value(false));

    registrar(control, "SEGUIMIENTO").andExpect(status().isCreated());
    get("/api/v1/recordatorios/seguimientos").andExpect(jsonPath("$[0].enviado").value(true));
  }

  @Test
  void noSeRegistraEnvioDeUnControlCerrado() throws Exception {
    String juan = crearPaciente("Juan", "987654321", true);
    String control = agendar(juan, hoy, null);
    mockMvc.perform(
        patch("/api/v1/controles/" + control + "/estado")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("estado", "ASISTIO")));

    registrar(control, "PREVIO").andExpect(status().isConflict());
  }

  @Test
  void alCerrarseElControlGuardaElDiaReal() throws Exception {
    String juan = crearPaciente("Juan", "987654321", true);
    String control = agendar(juan, hoy.plusDays(10), null);

    mockMvc
        .perform(
            patch("/api/v1/controles/" + control + "/estado")
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("estado", "ASISTIO")))
        .andExpect(jsonPath("$.control.fecha").value(hoy.plusDays(10).toString()))
        .andExpect(jsonPath("$.control.cerradoEn").value(hoy.toString()));
  }

  @Test
  void cambiaLaHoraDelAvisoDiario() throws Exception {
    mockMvc
        .perform(
            patch("/api/v1/auth/yo")
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("horaNotificacion", "17:45")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.horaNotificacion", startsWith("17:45")));

    get("/api/v1/auth/yo").andExpect(jsonPath("$.horaNotificacion", startsWith("17:45")));
  }

  @Test
  void otroUsuarioNoPuedeRegistrarEnviosAjenos() throws Exception {
    String juan = crearPaciente("Juan", "987654321", true);
    String control = agendar(juan, hoy.plusDays(1), null);
    crearUsuario("otro@gerenzdent.test", PASSWORD);
    String otro =
        "Bearer " + JsonPath.read(login("otro@gerenzdent.test", PASSWORD), "$.accessToken");

    mockMvc
        .perform(
            post("/api/v1/controles/" + control + "/recordatorios")
                .header("Authorization", otro)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("tipo", "PREVIO")))
        .andExpect(status().isNotFound());
    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/recordatorios/pendientes")
                .header("Authorization", otro))
        .andExpect(jsonPath("$", hasSize(0)));
  }
}
