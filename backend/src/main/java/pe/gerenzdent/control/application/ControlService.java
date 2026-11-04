package pe.gerenzdent.control.application;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.control.domain.EstadoControl;
import pe.gerenzdent.control.domain.PlanTratamiento;
import pe.gerenzdent.control.infrastructure.ControlRepository;
import pe.gerenzdent.control.infrastructure.PlanTratamientoRepository;
import pe.gerenzdent.paciente.application.PacienteService;
import pe.gerenzdent.paciente.domain.Paciente;
import pe.gerenzdent.shared.config.Calendario;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.tratamiento.domain.Tratamiento;
import pe.gerenzdent.tratamiento.infrastructure.TratamientoRepository;

/** Casos de uso de controles (HU-11 a HU-14). */
@Service
public class ControlService {

  /** Máximo rango de la agenda, para no traer años de datos por error. */
  public static final int DIAS_MAX_AGENDA = 62;

  private static final DateTimeFormatter FECHA_CORTA =
      DateTimeFormatter.ofPattern("EEE d 'de' MMMM", Locale.forLanguageTag("es-PE"));

  private final ControlRepository controles;
  private final PlanTratamientoRepository planes;
  private final TratamientoRepository tratamientos;
  private final PacienteService pacientes;
  private final Calendario calendario;

  public ControlService(
      ControlRepository controles,
      PlanTratamientoRepository planes,
      TratamientoRepository tratamientos,
      PacienteService pacientes,
      Calendario calendario) {
    this.controles = controles;
    this.planes = planes;
    this.tratamientos = tratamientos;
    this.pacientes = pacientes;
    this.calendario = calendario;
  }

  public record NuevoControl(
      UUID pacienteId,
      UUID tratamientoId,
      LocalDate fecha,
      LocalTime hora,
      String nota,
      Integer piezas) {}

  /** Control con su paciente (para listas de agenda y vencidos). */
  public record ControlConPaciente(Control control, Paciente paciente) {}

  /** Resultado de cambiar el estado: al marcar ASISTIO se sugiere el siguiente control (RN-03). */
  public record CambioDeEstado(Control control, Optional<LocalDate> siguienteFechaSugerida) {}

  /**
   * Agenda el próximo control. Reutiliza el plan activo de ese paciente + tratamiento o crea uno
   * nuevo. Solo puede haber un control abierto por plan.
   */
  @Transactional
  public Control agendar(UUID usuarioId, NuevoControl datos) {
    Paciente paciente = pacienteActivo(usuarioId, datos.pacienteId());
    Tratamiento tratamiento = tratamientoActivo(datos.tratamientoId());
    LocalDate hoy = calendario.hoy();

    PlanTratamiento plan =
        planes
            .findByPacienteIdAndTratamientoIdAndEstado(
                paciente.getId(), tratamiento.getId(), PlanTratamiento.Estado.ACTIVO)
            .orElseGet(() ->
                planes.save(
                    new PlanTratamiento(paciente.getId(), tratamiento, datos.piezas(), hoy)));

    controles
        .abiertoDelPlan(plan.getId(), EstadoControl.abiertos())
        .ifPresent(existente -> {
          throw new Conflicto(
              "%s ya tiene un control de %s pendiente para el %s."
                  .formatted(
                      paciente.getNombre(),
                      tratamiento.getNombre(),
                      FECHA_CORTA.format(existente.getFecha())),
              Map.of(
                  "controlExistenteId", existente.getId(),
                  "fechaExistente", existente.getFecha().toString()));
        });

    return controles.saveAndFlush(
        new Control(plan, datos.fecha(), datos.hora(), datos.nota(), hoy));
  }

  @Transactional
  public CambioDeEstado cambiarEstado(UUID usuarioId, UUID controlId, EstadoControl destino) {
    if (destino == null) {
      throw new DatoInvalido("estado", "Indica el nuevo estado.");
    }
    Control control = obtener(usuarioId, controlId);
    control.cambiarEstado(destino, calendario.hoy());

    Optional<LocalDate> sugerencia = Optional.empty();
    if (destino == EstadoControl.ASISTIO) {
      Paciente paciente = pacientes.obtener(usuarioId, control.getPlan().getPacienteId());
      sugerencia =
          control.getPlan().getTratamiento().fechaSugerida(calendario.hoy(), paciente.getEdad());
    }
    return new CambioDeEstado(controles.saveAndFlush(control), sugerencia);
  }

  /** Marca que se envió un recordatorio: PENDIENTE pasa a RECORDADO (HU-17). */
  @Transactional
  public Control registrarRecordatorio(UUID usuarioId, UUID controlId) {
    Control control = obtener(usuarioId, controlId);
    control.registrarRecordatorio();
    return controles.saveAndFlush(control);
  }

  @Transactional
  public Control reprogramar(UUID usuarioId, UUID controlId, LocalDate fecha, LocalTime hora) {
    Control control = obtener(usuarioId, controlId);
    control.reprogramar(fecha, hora, calendario.hoy());
    return controles.saveAndFlush(control);
  }

  @Transactional(readOnly = true)
  public Control obtener(UUID usuarioId, UUID controlId) {
    return controles
        .buscarDelUsuario(controlId, usuarioId)
        .orElseThrow(() -> new RecursoNoEncontrado("Control no encontrado."));
  }

  /** Todos los controles del paciente, el más reciente primero (ficha, HU-05). */
  @Transactional(readOnly = true)
  public List<Control> historial(UUID usuarioId, UUID pacienteId) {
    pacientes.obtener(usuarioId, pacienteId); // verifica que el paciente es del usuario
    return controles.historialDePaciente(pacienteId);
  }

  @Transactional(readOnly = true)
  public List<ControlConPaciente> agenda(UUID usuarioId, LocalDate desde, LocalDate hasta) {
    LocalDate inicio = desde == null ? calendario.hoy() : desde;
    LocalDate fin = hasta == null ? inicio.plusDays(7) : hasta;
    if (fin.isBefore(inicio)) {
      throw new DatoInvalido("hasta", "La fecha final no puede ser anterior a la inicial.");
    }
    if (inicio.plusDays(DIAS_MAX_AGENDA).isBefore(fin)) {
      throw new DatoInvalido("hasta", "El rango máximo es de %d días.".formatted(DIAS_MAX_AGENDA));
    }
    return conPaciente(controles.agenda(usuarioId, inicio, fin, EstadoControl.abiertos()));
  }

  @Transactional(readOnly = true)
  public List<ControlConPaciente> vencidos(UUID usuarioId) {
    return conPaciente(controles.vencidos(usuarioId, calendario.hoy(), EstadoControl.abiertos()));
  }

  /** Fecha sugerida para un control nuevo (HU-09). Vacío si el tratamiento no tiene intervalo. */
  @Transactional(readOnly = true)
  public Optional<LocalDate> sugerirFecha(UUID usuarioId, UUID pacienteId, UUID tratamientoId) {
    Paciente paciente = pacientes.obtener(usuarioId, pacienteId);
    return tratamientoActivo(tratamientoId).fechaSugerida(calendario.hoy(), paciente.getEdad());
  }

  public LocalDate hoy() {
    return calendario.hoy();
  }

  private Paciente pacienteActivo(UUID usuarioId, UUID pacienteId) {
    if (pacienteId == null) {
      throw new DatoInvalido("pacienteId", "Indica el paciente.");
    }
    Paciente paciente = pacientes.obtener(usuarioId, pacienteId);
    if (paciente.isArchivado()) {
      throw new Conflicto(
          "%s está archivado. Recupéralo para agendarle un control."
              .formatted(paciente.getNombre()),
          Map.of());
    }
    return paciente;
  }

  private Tratamiento tratamientoActivo(UUID tratamientoId) {
    if (tratamientoId == null) {
      throw new DatoInvalido("tratamientoId", "Elige el tratamiento.");
    }
    return tratamientos
        .findById(tratamientoId)
        .filter(Tratamiento::isActivo)
        .orElseThrow(() -> new RecursoNoEncontrado("Tratamiento no encontrado."));
  }

  private static List<ControlConPaciente> conPaciente(List<Object[]> filas) {
    return filas.stream()
        .map(f -> new ControlConPaciente((Control) f[0], (Paciente) f[1]))
        .toList();
  }
}
