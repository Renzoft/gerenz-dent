package pe.gerenzdent.paciente;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;
import pe.gerenzdent.PruebaIntegracion;

class PacienteIntegracionTest extends PruebaIntegracion {

  private String autorizacion;

  @BeforeEach
  void iniciarSesion() throws Exception {
    autorizacion = autorizacion();
  }

  private ResultActions crear(String cuerpo) throws Exception {
    return mockMvc.perform(
        post("/api/v1/pacientes")
            .header("Authorization", autorizacion)
            .contentType(MediaType.APPLICATION_JSON)
            .content(cuerpo));
  }

  private String crearId(String nombre, String whatsapp) throws Exception {
    String respuesta =
        crear(json("nombre", nombre, "whatsapp", whatsapp))
            .andExpect(status().isCreated())
            .andReturn()
            .getResponse()
            .getContentAsString();
    return JsonPath.read(respuesta, "$.id");
  }

  private ResultActions listar(String parametros) throws Exception {
    return mockMvc.perform(
        get("/api/v1/pacientes?" + parametros).header("Authorization", autorizacion));
  }

  @Test
  void creaUnPacienteSoloConNombreYWhatsapp() throws Exception {
    crear(json("nombre", "  Juan   Pérez ", "whatsapp", "987 654 321"))
        .andExpect(status().isCreated())
        .andExpect(header().string("Location", containsString("/api/v1/pacientes/")))
        .andExpect(jsonPath("$.nombre").value("Juan Pérez"))
        .andExpect(jsonPath("$.whatsapp").value("+51987654321"))
        .andExpect(jsonPath("$.consienteWhatsapp").value(true))
        .andExpect(jsonPath("$.archivado").value(false))
        .andExpect(jsonPath("$.edad").doesNotExist());
  }

  @Test
  void guardaLosDatosOpcionales() throws Exception {
    crear(
            json(
                "nombre",
                "Ana Ríos",
                "whatsapp",
                "+51912345678",
                "edad",
                9,
                "alergias",
                "Penicilina",
                "nota",
                "Viene con su mamá",
                "consienteWhatsapp",
                false))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.edad").value(9))
        .andExpect(jsonPath("$.alergias").value("Penicilina"))
        .andExpect(jsonPath("$.nota").value("Viene con su mamá"))
        .andExpect(jsonPath("$.consienteWhatsapp").value(false));
  }

  @Test
  void validaLosCamposObligatorios() throws Exception {
    crear(json("nombre", "", "whatsapp", "", "edad", 150))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.nombre").exists())
        .andExpect(jsonPath("$.errores.whatsapp").value("Ingresa el número de WhatsApp"))
        .andExpect(jsonPath("$.errores.edad").value("La edad máxima es 120"));
  }

  @Test
  void rechazaUnWhatsappInvalidoIndicandoElCampo() throws Exception {
    crear(json("nombre", "Juan", "whatsapp", "12345"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errores.whatsapp").exists());
  }

  @Test
  void noPermiteDosPacientesActivosConElMismoNumero() throws Exception {
    String id = crearId("Juan Pérez", "987654321");

    crear(json("nombre", "Otro", "whatsapp", "+51 987 654 321"))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.pacienteExistenteId").value(id))
        .andExpect(jsonPath("$.pacienteExistenteNombre").value("Juan Pérez"));
  }

  @Test
  void unNumeroArchivadoPuedeReutilizarseYNoSePuedeDesarchivarSiChoca() throws Exception {
    String viejo = crearId("Paciente Viejo", "987654321");
    mockMvc
        .perform(
            patch("/api/v1/pacientes/" + viejo + "/archivar").header("Authorization", autorizacion))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.archivado").value(true));

    crearId("Paciente Nuevo", "987654321");

    mockMvc
        .perform(
            patch("/api/v1/pacientes/" + viejo + "/desarchivar")
                .header("Authorization", autorizacion))
        .andExpect(status().isConflict());
  }

  @Test
  void buscaPorParteDelNombreSinImportarTildesNiMayusculas() throws Exception {
    crearId("José Pérez", "987654321");
    crearId("María Ñañez", "912345678");
    crearId("Pedro Gómez", "923456789");

    listar("q=PEREZ")
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.contenido", hasSize(1)))
        .andExpect(jsonPath("$.contenido[0].nombre").value("José Pérez"));
    listar("q=nan").andExpect(jsonPath("$.contenido[0].nombre").value("María Ñañez"));
  }

  @Test
  void buscaPorParteDelNumero() throws Exception {
    crearId("José Pérez", "987654321");
    crearId("María Ñañez", "912345678");

    listar("q=345 678")
        .andExpect(jsonPath("$.contenido", hasSize(1)))
        .andExpect(jsonPath("$.contenido[0].nombre").value("María Ñañez"));
  }

  @Test
  void listaEnOrdenAlfabeticoYPaginado() throws Exception {
    crearId("Carla", "911111111");
    crearId("álvaro", "922222222");
    crearId("Beto", "933333333");

    listar("tamano=2")
        .andExpect(jsonPath("$.contenido[*].nombre", contains("álvaro", "Beto")))
        .andExpect(jsonPath("$.totalElementos").value(3))
        .andExpect(jsonPath("$.totalPaginas").value(2));
    listar("tamano=2&pagina=1").andExpect(jsonPath("$.contenido[*].nombre", contains("Carla")));
  }

  @Test
  void losArchivadosSoloAparecenEnSuFiltro() throws Exception {
    String id = crearId("Juan", "987654321");
    crearId("Ana", "912345678");
    mockMvc.perform(
        patch("/api/v1/pacientes/" + id + "/archivar").header("Authorization", autorizacion));

    listar("").andExpect(jsonPath("$.contenido[*].nombre", contains("Ana")));
    listar("archivados=true").andExpect(jsonPath("$.contenido[*].nombre", contains("Juan")));
  }

  @Test
  void editaUnPaciente() throws Exception {
    String id = crearId("Juan", "987654321");

    mockMvc
        .perform(
            put("/api/v1/pacientes/" + id)
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    json("nombre", "Juan Pérez", "whatsapp", "912345678", "alergias", "Látex")))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.nombre").value("Juan Pérez"))
        .andExpect(jsonPath("$.whatsapp").value("+51912345678"))
        .andExpect(jsonPath("$.alergias").value("Látex"));
  }

  @Test
  void editarConservandoSuPropioNumeroNoEsConflicto() throws Exception {
    String id = crearId("Juan", "987654321");

    mockMvc
        .perform(
            put("/api/v1/pacientes/" + id)
                .header("Authorization", autorizacion)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json("nombre", "Juan P.", "whatsapp", "987654321")))
        .andExpect(status().isOk());
  }

  @Test
  void obtenerUnPacienteInexistenteDa404() throws Exception {
    mockMvc
        .perform(
            get("/api/v1/pacientes/00000000-0000-0000-0000-000000000000")
                .header("Authorization", autorizacion))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.detail").value("Paciente no encontrado."));
  }

  @Test
  void otroUsuarioNoPuedeVerNiEditarLosPacientes() throws Exception {
    String id = crearId("Juan", "987654321");

    crearUsuario("otro@gerenzdent.test", PASSWORD);
    String otro =
        "Bearer " + JsonPath.read(login("otro@gerenzdent.test", PASSWORD), "$.accessToken");

    mockMvc
        .perform(get("/api/v1/pacientes/" + id).header("Authorization", otro))
        .andExpect(status().isNotFound());
    mockMvc
        .perform(get("/api/v1/pacientes").header("Authorization", otro))
        .andExpect(jsonPath("$.contenido", hasSize(0)));
    mockMvc
        .perform(patch("/api/v1/pacientes/" + id + "/archivar").header("Authorization", otro))
        .andExpect(status().isNotFound());
  }
}
