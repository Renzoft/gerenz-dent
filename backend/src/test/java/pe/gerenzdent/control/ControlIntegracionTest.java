package pe.gerenzdent.control;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import pe.gerenzdent.PruebaIntegracion;
import pe.gerenzdent.shared.config.Calendario;

class ControlIntegracionTest extends PruebaIntegracion {

  @Autowired Calendario calendario;

  private String autorizacion;
  private LocalDate hoy;
  private String brackets;
  private String fluor;
  private String puente;

  @BeforeEach
  void preparar() throws Exception {
    autorizacion = autorizacion();
    hoy = calendario.hoy();
    brackets = idTratamiento("Brackets (ortodoncia)");
    fluor = idTratamiento("Aplicación de flúor");
    puente = idTratamiento("Puente de zirconio");
  }

  private String idTratamiento(String nombre) {
    return jdbc.queryForObject(
        "SELECT id::text FROM tratamiento WHERE nombre = ?", String.class, nombre);
  }

  private String crearPaciente(String nombre, String whatsapp, Integer edad) throws Exception {
    String r =
        mockMvc
            .perform(
                post("/api/v1/pacientes")
                    .header("Authorization", autorizacion)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json("nombre", nombre, "whatsapp", whatsapp, "edad", edad)))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    return JsonPath.read(r, "$.id");
  }

  private ResultActions agendar(Object... campos) throws Exception {
    return mockMvc.perform(
        post("/api/v1/controles")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json(campos)));
  }

  private String agendarId(String pacienteId, String tratamientoId, LocalDate fecha)
      throws Exception {
    String r =
        agendar("pacienteId", pacienteId, "tratamientoId", tratamientoId, "fecha", fecha.toString())
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    return JsonPath.read(r, "$.id");
  }

  private ResultActions cambiarEstado(String controlId, String estado) throws Exception {
    return mockMvc.perform(
        patch("/api/v1/controles/" + controlId + "/estado")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("estado", estado)));
  }

  private ResultActions get(String ruta) throws Exception {
    return mockMvc.perform(
        org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(ruta)
            .header("Authorization", autorizacion));
  }

  @Test
  void elCatalogoTieneLos14TratamientosDelConsultorio() throws Exception {
    get("/api/v1/tratamientos")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(14)))
        .andExpect(jsonPath("$[0].nombre").value("Blanqueamiento dental"))
        .andExpect(jsonPath("$[1].tipoPrecio").value("INICIAL_MAS_MENSUAL"))
        .andExpect(jsonPath("$[1].precioMensual").value(100.0))
        .andExpect(jsonPath("$[12].nombre").value("Aplicación de flúor"))
        .andExpect(jsonPath("$[12].edadMaximaControl").value(12));
  }

  @Test
  void agendaUnControlConHoraYNota() throws Exception {
    String paciente = crearPaciente("Juan Pérez", "987654321", null);

    agendar(
            "pacienteId",
            paciente,
            "tratamientoId",
            brackets,
            "fecha",
            hoy.plusDays(30).toString(),
            "hora",
            "19:30",
            "nota",
            "Cambio de ligas")
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.estado").value("PENDIENTE"))
        .andExpect(jsonPath("$.hora").value(containsString("19:30")))
        .andExpect(jsonPath("$.nota").value("Cambio de ligas"))
        .andExpect(jsonPath("$.tratamiento.nombre").value("Brackets (ortodoncia)"))
        .andExpect(jsonPath("$.vencido").value(false));
  }

  @Test
  void validaLosDatosDelControl() throws Exception {
    String paciente = crearPaciente("Juan", "987654321", null);

    agendar("pacienteId", paciente)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.tratamientoId").value("Elige el tratamiento"))
        .andExpect(jsonPath("$.errores.fecha").value("Elige la fecha del control"));

    agendar("pacienteId", paciente, "tratamientoId", brackets, "fecha", hoy.minusDays(1).toString())
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.fecha").value("La fecha no puede ser anterior a hoy."));
  }

  @Test
  void soloUnControlAbiertoPorTratamiento() throws Exception {
    String paciente = crearPaciente("Juan", "987654321", null);
    String primero = agendarId(paciente, brackets, hoy.plusDays(30));

    agendar("pacienteId", paciente, "tratamientoId", brackets, "fecha", hoy.plusDays(40).toString())
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.controlExistenteId").value(primero));

    // Otro tratamiento sí se puede agendar en paralelo.
    agendarId(paciente, puente, hoy.plusDays(7));
  }

  @Test
  void alMarcarAsistioSugiereElSiguienteYPermiteAgendarlo() throws Exception {
    String paciente = crearPaciente("Juan", "987654321", null);
    String control = agendarId(paciente, brackets, hoy);

    cambiarEstado(control, "ASISTIO")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.control.estado").value("ASISTIO"))
        .andExpect(jsonPath("$.siguienteFechaSugerida").value(hoy.plusDays(30).toString()));

    agendarId(paciente, brackets, hoy.plusDays(30)); // mismo plan, nuevo control
    Integer planes = jdbc.queryForObject("SELECT count(*) FROM plan_tratamiento", Integer.class);
    org.assertj.core.api.Assertions.assertThat(planes).isEqualTo(1);
  }

  @Test
  void fluorSoloSugiereFechaParaNinosHasta12() throws Exception {
    String nino = crearPaciente("Niño", "911111111", 8);
    String adulto = crearPaciente("Adulto", "922222222", 30);

    get("/api/v1/controles/sugerencia?pacienteId=" + nino + "&tratamientoId=" + fluor)
        .andExpect(jsonPath("$.fecha").value(hoy.plusDays(180).toString()));
    get("/api/v1/controles/sugerencia?pacienteId=" + adulto + "&tratamientoId=" + fluor)
        .andExpect(jsonPath("$.fecha").doesNotExist());
  }

  @Test
  void noPermiteTransicionesInvalidas() throws Exception {
    String paciente = crearPaciente("Juan", "987654321", null);
    String control = agendarId(paciente, brackets, hoy);
    cambiarEstado(control, "CANCELADO").andExpect(status().isOk());

    cambiarEstado(control, "ASISTIO")
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.estadoActual").value("CANCELADO"));
  }

  @Test
  void reprogramarCambiaLaFechaYVuelveAPendiente() throws Exception {
    String paciente = crearPaciente("Juan", "987654321", null);
    String control = agendarId(paciente, brackets, hoy);
    cambiarEstado(control, "CONFIRMADO");

    mockMvc
        .perform(
            patch("/api/v1/controles/" + control + "/fecha")
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("fecha", hoy.plusDays(5).toString())))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.estado").value("PENDIENTE"))
        .andExpect(jsonPath("$.fecha").value(hoy.plusDays(5).toString()));
  }

  @Test
  void laAgendaMuestraLosAbiertosDelRangoConSuPaciente() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    String ana = crearPaciente("Ana", "912345678", null);
    agendarId(juan, brackets, hoy.plusDays(1));
    agendarId(ana, puente, hoy.plusDays(1));
    String cerrado = agendarId(ana, brackets, hoy.plusDays(2));
    cambiarEstado(cerrado, "CANCELADO");
    agendarId(juan, puente, hoy.plusDays(20)); // fuera del rango por defecto

    get("/api/v1/controles")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(2)))
        .andExpect(jsonPath("$[*].paciente.nombre", contains("Ana", "Juan")))
        .andExpect(jsonPath("$[0].paciente.whatsapp").value("+51912345678"));

    String manana = hoy.plusDays(1).toString();
    get("/api/v1/controles?desde=" + manana + "&hasta=" + manana)
        .andExpect(jsonPath("$", hasSize(2)));
  }

  @Test
  void elCalendarioIncluyeLosQueAsistieronONoVinieronPeroNoLosCancelados() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    String ana = crearPaciente("Ana", "912345678", null);
    String luis = crearPaciente("Luis", "923456789", null);
    String asistio = agendarId(juan, brackets, hoy);
    cambiarEstado(asistio, "ASISTIO").andExpect(status().isOk());
    String cancelado = agendarId(ana, puente, hoy);
    cambiarEstado(cancelado, "CANCELADO").andExpect(status().isOk());
    agendarId(luis, puente, hoy);
    String dia = hoy.toString();

    get("/api/v1/controles?desde=" + dia + "&hasta=" + dia)
        .andExpect(jsonPath("$[*].paciente.nombre", contains("Luis")));
    get("/api/v1/controles?desde=" + dia + "&hasta=" + dia + "&cerrados=true")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$", hasSize(2)))
        .andExpect(jsonPath("$[*].paciente.nombre", containsInAnyOrder("Juan", "Luis")))
        .andExpect(jsonPath("$[?(@.paciente.nombre == 'Juan')].estado", contains("ASISTIO")));
  }

  @Test
  void losVencidosSonLosAbiertosConFechaPasadaDePacientesActivos() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    String ana = crearPaciente("Ana", "912345678", null);
    String vencidoJuan = agendarId(juan, brackets, hoy);
    String vencidoAna = agendarId(ana, brackets, hoy);
    agendarId(juan, puente, hoy.plusDays(3));
    // Simula que pasaron 4 días (la API no deja crear controles con fecha pasada).
    jdbc.update(
        "UPDATE control SET fecha = ? WHERE id::text IN (?, ?)",
        hoy.minusDays(4),
        vencidoJuan,
        vencidoAna);
    mockMvc.perform(
        patch("/api/v1/pacientes/" + ana + "/archivar").header("Authorization", autorizacion));

    get("/api/v1/controles/vencidos")
        .andExpect(jsonPath("$", hasSize(1)))
        .andExpect(jsonPath("$[0].paciente.nombre").value("Juan"))
        .andExpect(jsonPath("$[0].vencido").value(true))
        .andExpect(jsonPath("$[0].diasAtraso").value(4));
  }

  @Test
  void elHistorialDelPacienteVaDelMasRecienteAlMasAntiguo() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    String primero = agendarId(juan, brackets, hoy);
    cambiarEstado(primero, "ASISTIO");
    agendarId(juan, brackets, hoy.plusDays(30));

    get("/api/v1/pacientes/" + juan + "/controles")
        .andExpect(jsonPath("$", hasSize(2)))
        .andExpect(jsonPath("$[0].estado").value("PENDIENTE"))
        .andExpect(jsonPath("$[1].estado").value("ASISTIO"));
  }

  @Test
  void noSeAgendaAPacientesArchivados() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    mockMvc.perform(
        patch("/api/v1/pacientes/" + juan + "/archivar").header("Authorization", autorizacion));

    agendar("pacienteId", juan, "tratamientoId", brackets, "fecha", hoy.toString())
        .andExpect(status().isConflict());
  }

  @Test
  void otroUsuarioNoVeNiModificaLosControles() throws Exception {
    String juan = crearPaciente("Juan", "987654321", null);
    String control = agendarId(juan, brackets, hoy);

    crearUsuario("otro@gerenzdent.test", PASSWORD);
    String otro =
        "Bearer " + JsonPath.read(login("otro@gerenzdent.test", PASSWORD), "$.accessToken");

    mockMvc
        .perform(
            patch("/api/v1/controles/" + control + "/estado")
                .header("Authorization", otro)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("estado", "CANCELADO")))
        .andExpect(status().isNotFound());
    mockMvc
        .perform(
            org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(
                    "/api/v1/controles")
                .header("Authorization", otro))
        .andExpect(jsonPath("$", hasSize(0)));
    mockMvc
        .perform(
            post("/api/v1/controles")
                .header("Authorization", otro)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json("pacienteId", juan, "tratamientoId", brackets, "fecha", hoy.toString())))
        .andExpect(status().isNotFound());
  }
}
