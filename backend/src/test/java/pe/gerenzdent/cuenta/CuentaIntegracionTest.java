package pe.gerenzdent.cuenta;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
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

class CuentaIntegracionTest extends PruebaIntegracion {

  @Autowired Calendario calendario;

  private String autorizacion;
  private LocalDate hoy;

  @BeforeEach
  void preparar() throws Exception {
    autorizacion = autorizacion();
    hoy = calendario.hoy();
  }

  private String tratamiento(String nombre) {
    return jdbc.queryForObject(
        "SELECT id::text FROM tratamiento WHERE nombre = ?", String.class, nombre);
  }

  private String paciente(String nombre, String whatsapp) throws Exception {
    return JsonPath.read(
        mockMvc
            .perform(
                post("/api/v1/pacientes")
                    .header("Authorization", autorizacion)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json("nombre", nombre, "whatsapp", whatsapp)))
            .andReturn()
            .getResponse()
            .getContentAsString(),
        "$.id");
  }

  private ResultActions agendar(Object... campos) throws Exception {
    return mockMvc.perform(
        post("/api/v1/controles")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json(campos)));
  }

  private String agendarId(String pacienteId, String tratamientoId) throws Exception {
    return JsonPath.read(
        agendar("pacienteId", pacienteId, "tratamientoId", tratamientoId, "fecha", hoy.toString())
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString(),
        "$.id");
  }

  private ResultActions get(String ruta) throws Exception {
    return mockMvc.perform(MockMvcRequestBuilders.get(ruta).header("Authorization", autorizacion));
  }

  private ResultActions asistio(String controlId) throws Exception {
    return mockMvc.perform(
        patch("/api/v1/controles/" + controlId + "/estado")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("estado", "ASISTIO")));
  }

  private String planDe(String pacienteId) throws Exception {
    return JsonPath.read(
        get("/api/v1/pacientes/" + pacienteId + "/cuenta")
            .andReturn()
            .getResponse()
            .getContentAsString(),
        "$.planes[0].planId");
  }

  private ResultActions pagar(String planId, Object monto, String medio) throws Exception {
    return mockMvc.perform(
        post("/api/v1/planes/" + planId + "/pagos")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("monto", monto, "medio", medio)));
  }

  @Test
  void tratamientoFijoGeneraUnCargoConElPrecioDelCatalogo() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Extracción dental"));

    get("/api/v1/pacientes/" + juan + "/cuenta")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.deuda").value(70.0))
        .andExpect(jsonPath("$.planes[0].tratamiento.nombre").value("Extracción dental"))
        .andExpect(jsonPath("$.planes[0].cargos[0].concepto").value("TRATAMIENTO"))
        .andExpect(jsonPath("$.planes[0].cargos[0].monto").value(70.0));
  }

  @Test
  void porPiezaMultiplicaPorLasPiezas() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendar(
            "pacienteId",
            juan,
            "tratamientoId",
            tratamiento("Puente de zirconio"),
            "fecha",
            hoy.toString(),
            "piezas",
            2)
        .andExpect(status().isCreated());

    get("/api/v1/pacientes/" + juan + "/cuenta").andExpect(jsonPath("$.deuda").value(1400.0));
  }

  @Test
  void bracketsCobraElInicialYUnaCuotaCadaVezQueAsiste() throws Exception {
    String juan = paciente("Juan", "987654321");
    String brackets = tratamiento("Brackets (ortodoncia)");
    String primero = agendarId(juan, brackets);
    get("/api/v1/pacientes/" + juan + "/cuenta").andExpect(jsonPath("$.deuda").value(500.0));

    asistio(primero);
    String segundo = agendarId(juan, brackets);
    asistio(segundo);

    get("/api/v1/pacientes/" + juan + "/cuenta")
        .andExpect(jsonPath("$.deuda").value(700.0))
        .andExpect(jsonPath("$.planes", hasSize(1)))
        .andExpect(
            jsonPath("$.planes[0].cargos[*].concepto", contains("INICIAL", "MENSUAL", "MENSUAL")));
  }

  @Test
  void noVinoNoGeneraCuota() throws Exception {
    String juan = paciente("Juan", "987654321");
    String control = agendarId(juan, tratamiento("Brackets (ortodoncia)"));
    mockMvc.perform(
        patch("/api/v1/controles/" + control + "/estado")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(json("estado", "NO_ASISTIO")));

    get("/api/v1/pacientes/" + juan + "/cuenta").andExpect(jsonPath("$.deuda").value(500.0));
  }

  @Test
  void alAgendarSePuedeAcordarOtroCostoYRegistrarUnPago() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendar(
            "pacienteId",
            juan,
            "tratamientoId",
            tratamiento("Blanqueamiento dental"),
            "fecha",
            hoy.toString(),
            "costo",
            150,
            "pagoInicial",
            50,
            "medioPago",
            "YAPE")
        .andExpect(status().isCreated());

    get("/api/v1/pacientes/" + juan + "/cuenta")
        .andExpect(jsonPath("$.deuda").value(100.0))
        .andExpect(jsonPath("$.planes[0].pagos[0].medio").value("YAPE"));
  }

  @Test
  void unPagoInicialMayorAlCostoNoGuardaNada() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendar(
            "pacienteId",
            juan,
            "tratamientoId",
            tratamiento("Extracción dental"),
            "fecha",
            hoy.toString(),
            "pagoInicial",
            100)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.pagoInicial").exists());

    get("/api/v1/pacientes/" + juan + "/controles").andExpect(jsonPath("$", hasSize(0)));
  }

  @Test
  void registrarYAnularPagos() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Prótesis dental completa (juego)"));
    String plan = planDe(juan);

    String respuesta =
        pagar(plan, 300, "EFECTIVO")
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.saldo").value(700.0))
            .andReturn()
            .getResponse()
            .getContentAsString();
    String pagoId = JsonPath.read(respuesta, "$.pagos[0].id");

    mockMvc
        .perform(
            patch("/api/v1/pagos/" + pagoId + "/anular")
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("motivo", "Registrado por error")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.saldo").value(1000.0))
        .andExpect(jsonPath("$.pagos[0].estado").value("ANULADO"))
        .andExpect(jsonPath("$.pagos[0].motivoAnulacion").value("Registrado por error"));
  }

  @Test
  void unPagoNoPuedeSuperarLaDeuda() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Extracción dental"));

    pagar(planDe(juan), 80, "EFECTIVO")
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.monto").value("El pago supera la deuda de S/ 70.00."));
  }

  @Test
  void descuentoAjustandoElCargoYCargoManual() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Prótesis dental completa (juego)"));
    String plan = planDe(juan);
    String cargoId =
        JsonPath.read(
            get("/api/v1/pacientes/" + juan + "/cuenta")
                .andReturn()
                .getResponse()
                .getContentAsString(),
            "$.planes[0].cargos[0].id");

    mockMvc
        .perform(
            patch("/api/v1/cargos/" + cargoId)
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("monto", 900)))
        .andExpect(jsonPath("$.saldo").value(900.0));

    mockMvc
        .perform(
            post("/api/v1/planes/" + plan + "/cargos")
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("descripcion", "Rebase", "monto", 120)))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.saldo").value(1020.0))
        .andExpect(jsonPath("$.cargos[1].concepto").value("OTRO"));
  }

  @Test
  void noSePuedeRebajarElCargoPorDebajoDeLoPagado() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Blanqueamiento dental"));
    String plan = planDe(juan);
    pagar(plan, 200, "EFECTIVO").andExpect(status().isCreated());
    String cargoId =
        JsonPath.read(
            get("/api/v1/pacientes/" + juan + "/cuenta")
                .andReturn()
                .getResponse()
                .getContentAsString(),
            "$.planes[0].cargos[0].id");

    mockMvc
        .perform(
            patch("/api/v1/cargos/" + cargoId)
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("monto", 150)))
        .andExpect(status().isBadRequest());
  }

  @Test
  void laListaDeDeudasVaDeMayorAMenorEIncluyeArchivados() throws Exception {
    String juan = paciente("Juan", "987654321");
    String ana = paciente("Ana", "912345678");
    String luis = paciente("Luis", "923456789");
    agendarId(juan, tratamiento("Extracción dental")); // 70
    agendarId(ana, tratamiento("Prótesis dental parcial acrílica")); // 400
    agendarId(luis, tratamiento("Aplicación de flúor")); // 50, luego pagado
    pagar(planDe(luis), 50, "PLIN").andExpect(status().isCreated());
    mockMvc.perform(
        patch("/api/v1/pacientes/" + ana + "/archivar").header("Authorization", autorizacion));

    get("/api/v1/deudas")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.total").value(470.0))
        .andExpect(jsonPath("$.cantidadPacientes").value(2))
        .andExpect(jsonPath("$.pacientes[*].nombre", contains("Ana", "Juan")))
        .andExpect(jsonPath("$.pacientes[0].archivado").value(true));
  }

  @Test
  void otroUsuarioNoVeNiPagaCuentasAjenas() throws Exception {
    String juan = paciente("Juan", "987654321");
    agendarId(juan, tratamiento("Extracción dental"));
    String plan = planDe(juan);
    crearUsuario("otro@gerenzdent.test", PASSWORD);
    String otro =
        "Bearer " + JsonPath.read(login("otro@gerenzdent.test", PASSWORD), "$.accessToken");

    mockMvc
        .perform(
            MockMvcRequestBuilders.get("/api/v1/pacientes/" + juan + "/cuenta")
                .header("Authorization", otro))
        .andExpect(status().isNotFound());
    mockMvc
        .perform(
            post("/api/v1/planes/" + plan + "/pagos")
                .header("Authorization", otro)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("monto", 10, "medio", "EFECTIVO")))
        .andExpect(status().isNotFound());
    mockMvc
        .perform(MockMvcRequestBuilders.get("/api/v1/deudas").header("Authorization", otro))
        .andExpect(jsonPath("$.total").value(0.0));
  }
}
