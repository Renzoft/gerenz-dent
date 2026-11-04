package pe.gerenzdent.paciente.application;

import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.paciente.domain.DatosPaciente;
import pe.gerenzdent.paciente.domain.Paciente;
import pe.gerenzdent.paciente.infrastructure.PacienteRepository;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.shared.domain.Textos;

/** Casos de uso de pacientes. Todo se filtra por el usuario dueño de los datos. */
@Service
public class PacienteService {

  public static final int TAMANO_PAGINA_MAX = 50;
  private static final int LONGITUD_MINIMA_BUSQUEDA_NUMERO = 3;
  private static final Sort ORDEN = Sort.by("nombreBusqueda").and(Sort.by("id"));

  private final PacienteRepository pacientes;

  public PacienteService(PacienteRepository pacientes) {
    this.pacientes = pacientes;
  }

  @Transactional
  public Paciente crear(UUID usuarioId, DatosPaciente datos) {
    Paciente paciente = new Paciente(usuarioId, datos);
    verificarNumeroLibre(usuarioId, paciente.getWhatsapp(), null);
    return pacientes.saveAndFlush(paciente);
  }

  @Transactional
  public Paciente actualizar(UUID usuarioId, UUID pacienteId, DatosPaciente datos) {
    Paciente paciente = obtener(usuarioId, pacienteId);
    paciente.actualizar(datos);
    if (!paciente.isArchivado()) {
      verificarNumeroLibre(usuarioId, paciente.getWhatsapp(), pacienteId);
    }
    return pacientes.saveAndFlush(paciente);
  }

  @Transactional(readOnly = true)
  public Paciente obtener(UUID usuarioId, UUID pacienteId) {
    return pacientes
        .findByIdAndUsuarioId(pacienteId, usuarioId)
        .orElseThrow(() -> new RecursoNoEncontrado("Paciente no encontrado."));
  }

  /**
   * Busca por parte del nombre (sin importar tildes) o, si el texto tiene 3+ dígitos, también por
   * parte del número. Ordenado alfabéticamente.
   */
  @Transactional(readOnly = true)
  public Page<Paciente> buscar(
      UUID usuarioId, String texto, boolean archivados, int pagina, int tamano) {
    PageRequest pageRequest =
        PageRequest.of(Math.max(pagina, 0), Math.clamp(tamano, 1, TAMANO_PAGINA_MAX), ORDEN);
    String busqueda = Textos.paraBusqueda(texto);
    if (busqueda.isEmpty()) {
      return pacientes.findByUsuarioIdAndArchivado(usuarioId, archivados, pageRequest);
    }
    String digitos = busqueda.replaceAll("\\D", "");
    if (digitos.length() >= LONGITUD_MINIMA_BUSQUEDA_NUMERO) {
      return pacientes.buscarPorNombreONumero(
          usuarioId, archivados, busqueda, digitos, pageRequest);
    }
    return pacientes.buscarPorNombre(usuarioId, archivados, busqueda, pageRequest);
  }

  @Transactional
  public Paciente archivar(UUID usuarioId, UUID pacienteId) {
    Paciente paciente = obtener(usuarioId, pacienteId);
    paciente.archivar();
    return paciente;
  }

  @Transactional
  public Paciente desarchivar(UUID usuarioId, UUID pacienteId) {
    Paciente paciente = obtener(usuarioId, pacienteId);
    if (paciente.isArchivado()) {
      verificarNumeroLibre(usuarioId, paciente.getWhatsapp(), pacienteId);
      paciente.desarchivar();
    }
    return pacientes.saveAndFlush(paciente);
  }

  /** Un número solo puede pertenecer a un paciente activo. Devuelve el id del que ya lo tiene. */
  private void verificarNumeroLibre(UUID usuarioId, String whatsapp, UUID excepto) {
    pacientes
        .findFirstByUsuarioIdAndWhatsappAndArchivadoFalse(usuarioId, whatsapp)
        .filter(existente -> !existente.getId().equals(excepto))
        .ifPresent(existente -> {
          throw new Conflicto(
              "Ya existe un paciente con ese número: " + existente.getNombre() + ".",
              Map.of(
                  "pacienteExistenteId", existente.getId(),
                  "pacienteExistenteNombre", existente.getNombre()));
        });
  }
}
