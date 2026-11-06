package pe.gerenzdent.control.application;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.control.domain.EstadoControl;
import pe.gerenzdent.control.domain.EventosControl;
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
  private final ApplicationEventPublisher eventos;

  public ControlService(
      ControlRepository controles,
      PlanTratamientoRepository planes,
      TratamientoRepository tratamientos,
      PacienteService pacientes,
      Calendario calendario,
      ApplicationEventPublisher eventos) {
    this.controles = controles;
    this.planes = planes;
    this.tratamientos = tratamientos;
    this.pacientes = pacientes;
    this.calendario = calendario;
    this.eventos = eventos;
  }

  /**
   * Datos para agendar. {@code costo}, {@code pagoInicial} y {@code medioPago} solo se usan si se
   * crea un plan nuevo (primer control de ese tratamiento).
   */
  public record NuevoControl(
      UUID pacienteId,
      UUID tratamientoId,
      LocalDate fecha,
      LocalTime hora,
      String nota,
      Integer piezas,
      BigDecimal costo,
      BigDecimal pagoInicial,
      String medioPago) {

    public NuevoControl(
        UUID pacienteId,
        UUID tratamientoId,
        LocalDate fecha,
        LocalTime hora,
        String nota,
        Integer piezas) {
      this(pacienteId, tratamientoId, fecha, hora, nota, piezas, null, null, null);
    }
  }

  /** Control con su paciente (para listas de agenda y vencidos). */
  public record ControlConPaciente(Control control, Paciente paciente) {}

  /** Resultado de "no vino": el control cerrado y, si se eligió fecha, el siguiente. */
  public record NoVino(Control cerrado, Optional<Control> siguiente) {}

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

    Optional<PlanTratamiento> planActivo =
        planes.findByPacienteIdAndTratamientoIdAndEstado(
            paciente.getId(), tratamiento.getId(), PlanTratamiento.Estado.ACTIVO);
    boolean planNuevo = planActivo.isEmpty();
    PlanTratamiento plan =
        planActivo.orElseGet(() ->
            planes.save(new PlanTratamiento(paciente.getId(), tratamiento, datos.piezas(), hoy)));

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

    Control control =
        controles.saveAndFlush(new Control(plan, datos.fecha(), datos.hora(), datos.nota(), hoy));
    if (planNuevo) {
      // El módulo "cuenta" genera el cargo (y el pago inicial, si lo hubo).
      eventos.publishEvent(
          new EventosControl.PlanCreado(
              plan, datos.costo(), datos.pagoInicial(), datos.medioPago(), hoy));
    }
    return control;
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
      // Brackets: el módulo "cuenta" carga la cuota mensual.
      eventos.publishEvent(new EventosControl.ControlAsistido(control, calendario.hoy()));
      Paciente paciente = pacientes.obtener(usuarioId, control.getPlan().getPacienteId());
      sugerencia =
          control.getPlan().getTratamiento().fechaSugerida(calendario.hoy(), paciente.getEdad());
    }
    return new CambioDeEstado(controles.saveAndFlush(control), sugerencia);
  }

  /**
   * El paciente no vino: el control queda como NO_ASISTIO (historial) y, si ya se sabe cuándo
   * vuelve, se agenda el siguiente del mismo plan en el mismo paso (sin cargos nuevos). Sin fecha,
   * el paciente queda en "No vinieron" para escribirle.
   */
  @Transactional
  public NoVino noVino(UUID usuarioId, UUID controlId, LocalDate nuevaFecha, LocalTime nuevaHora) {
    LocalDate hoy = calendario.hoy();
    Control control = obtener(usuarioId, controlId);
    control.cambiarEstado(EstadoControl.NO_ASISTIO, hoy);
    controles.saveAndFlush(control);
    if (nuevaFecha == null) {
      return new NoVino(control, Optional.empty());
    }
    Control siguiente =
        controles.saveAndFlush(new Control(control.getPlan(), nuevaFecha, nuevaHora, null, hoy));
    return new NoVino(control, Optional.of(siguiente));
  }

  /** Seguimiento enviado (HU-18): vale para vencidos y para los que no vinieron sin fecha. */
  @Transactional
  public Control registrarSeguimiento(UUID usuarioId, UUID controlId) {
    Control control = obtener(usuarioId, controlId);
    control.registrarSeguimiento();
    return controles.saveAndFlush(control);
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
    return agenda(usuarioId, desde, hasta, false);
  }

  /**
   * Controles entre dos fechas. Con {@code conCerrados} (calendario) incluye también los que
   * asistieron o no vinieron; los cancelados nunca.
   */
  @Transactional(readOnly = true)
  public List<ControlConPaciente> agenda(
      UUID usuarioId, LocalDate desde, LocalDate hasta, boolean conCerrados) {
    LocalDate inicio = desde == null ? calendario.hoy() : desde;
    LocalDate fin = hasta == null ? inicio.plusDays(7) : hasta;
    if (fin.isBefore(inicio)) {
      throw new DatoInvalido("hasta", "La fecha final no puede ser anterior a la inicial.");
    }
    if (inicio.plusDays(DIAS_MAX_AGENDA).isBefore(fin)) {
      throw new DatoInvalido("hasta", "El rango máximo es de %d días.".formatted(DIAS_MAX_AGENDA));
    }
    var estados = conCerrados ? EstadoControl.paraCalendario() : EstadoControl.abiertos();
    return conPaciente(controles.agenda(usuarioId, inicio, fin, estados));
  }

  @Transactional(readOnly = true)
  public List<ControlConPaciente> vencidos(UUID usuarioId) {
    return conPaciente(controles.vencidos(usuarioId, calendario.hoy(), EstadoControl.abiertos()));
  }

  /**
   * "No vinieron" (HU-18): los vencidos más los que se marcaron "no asistió" y siguen sin fecha
   * nueva. El más atrasado primero.
   */
  @Transactional(readOnly = true)
  public List<ControlConPaciente> noVinieron(UUID usuarioId) {
    List<ControlConPaciente> lista = new ArrayList<>(vencidos(usuarioId));
    lista.addAll(conPaciente(controles.noVinieronSinFecha(usuarioId, EstadoControl.abiertos())));
    lista.sort(
        Comparator.comparing((ControlConPaciente cp) -> cp.control().getFecha())
            .thenComparing(cp -> cp.paciente().getNombre()));
    return lista;
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
