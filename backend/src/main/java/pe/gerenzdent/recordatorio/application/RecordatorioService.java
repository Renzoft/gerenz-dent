package pe.gerenzdent.recordatorio.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.auth.application.AuthService;
import pe.gerenzdent.control.application.ControlService;
import pe.gerenzdent.control.application.ControlService.ControlConPaciente;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.paciente.domain.Paciente;
import pe.gerenzdent.recordatorio.domain.PlantillaMensaje;
import pe.gerenzdent.recordatorio.domain.ProveedorNotificaciones;
import pe.gerenzdent.recordatorio.domain.Recordatorio;
import pe.gerenzdent.recordatorio.infrastructure.RecordatorioRepository;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

/** Casos de uso de recordatorios (HU-15 a HU-19). */
@Service
public class RecordatorioService {

  private final ControlService controles;
  private final AuthService auth;
  private final RecordatorioRepository recordatorios;
  private final ProveedorNotificaciones proveedor;
  private final Clock reloj;

  public RecordatorioService(
      ControlService controles,
      AuthService auth,
      RecordatorioRepository recordatorios,
      ProveedorNotificaciones proveedor,
      Clock reloj) {
    this.controles = controles;
    this.auth = auth;
    this.recordatorios = recordatorios;
    this.proveedor = proveedor;
    this.reloj = reloj;
  }

  /**
   * Mensaje listo para enviar.
   *
   * @param enlace {@code null} si el paciente no autorizó recordatorios por WhatsApp
   * @param ultimoEnvio último recordatorio del mismo tipo, o {@code null}
   */
  public record MensajePreparado(
      Control control,
      Paciente paciente,
      Recordatorio.Tipo tipo,
      String mensaje,
      String enlace,
      Instant ultimoEnvio) {

    public boolean enviado() {
      return ultimoEnvio != null;
    }
  }

  /** Controles de una fecha (por defecto, mañana) con su recordatorio armado (HU-15, HU-16). */
  @Transactional(readOnly = true)
  public List<MensajePreparado> pendientes(UUID usuarioId, LocalDate fecha) {
    LocalDate hoy = controles.hoy();
    LocalDate dia = fecha == null ? hoy.plusDays(1) : fecha;
    if (dia.isBefore(hoy)) {
      throw new DatoInvalido("fecha", "Para fechas pasadas usa los seguimientos.");
    }
    String doctor = auth.usuarioActual(usuarioId).getNombre();
    List<ControlConPaciente> lista = controles.agenda(usuarioId, dia, dia);
    Map<UUID, Instant> envios = ultimosEnvios(lista, Recordatorio.Tipo.PREVIO);
    return lista.stream()
        .map(cp ->
            preparar(
                cp,
                Recordatorio.Tipo.PREVIO,
                PlantillaMensaje.recordatorio(datos(cp, doctor), hoy),
                envios))
        .toList();
  }

  /** "No vinieron" con el mensaje de seguimiento (HU-18): vencidos y no asistidos sin fecha. */
  @Transactional(readOnly = true)
  public List<MensajePreparado> seguimientos(UUID usuarioId) {
    String doctor = auth.usuarioActual(usuarioId).getNombre();
    List<ControlConPaciente> lista = controles.noVinieron(usuarioId);
    Map<UUID, Instant> envios = ultimosEnvios(lista, Recordatorio.Tipo.SEGUIMIENTO);
    return lista.stream()
        .map(cp ->
            preparar(
                cp,
                Recordatorio.Tipo.SEGUIMIENTO,
                PlantillaMensaje.seguimiento(datos(cp, doctor)),
                envios))
        .toList();
  }

  /** "Hoy" en Lima (ver {@code Calendario}). */
  public LocalDate hoy() {
    return controles.hoy();
  }

  /** El doctor confirma que envió el mensaje (HU-17). */
  @Transactional
  public Recordatorio registrarEnvio(UUID usuarioId, UUID controlId, Recordatorio.Tipo tipo) {
    if (tipo == null) {
      throw new DatoInvalido("tipo", "Indica el tipo de recordatorio.");
    }
    Control control =
        tipo == Recordatorio.Tipo.SEGUIMIENTO
            ? controles.registrarSeguimiento(usuarioId, controlId)
            : controles.registrarRecordatorio(usuarioId, controlId);
    return recordatorios.save(
        new Recordatorio(control.getId(), tipo, proveedor.canal(), reloj.instant()));
  }

  private MensajePreparado preparar(
      ControlConPaciente cp, Recordatorio.Tipo tipo, String mensaje, Map<UUID, Instant> envios) {
    Paciente p = cp.paciente();
    String enlace = p.isConsienteWhatsapp() ? proveedor.preparar(p.getWhatsapp(), mensaje) : null;
    return new MensajePreparado(
        cp.control(), p, tipo, mensaje, enlace, envios.get(cp.control().getId()));
  }

  private static PlantillaMensaje.Datos datos(ControlConPaciente cp, String doctor) {
    Control c = cp.control();
    return new PlantillaMensaje.Datos(
        cp.paciente().getNombre(),
        doctor,
        c.getPlan().getTratamiento().getNombre(),
        c.getFecha(),
        c.getHora());
  }

  /** Último envío de cada control (la consulta viene ordenada del más reciente al más antiguo). */
  private Map<UUID, Instant> ultimosEnvios(List<ControlConPaciente> lista, Recordatorio.Tipo tipo) {
    if (lista.isEmpty()) {
      return Map.of();
    }
    List<UUID> ids = lista.stream().map(cp -> cp.control().getId()).toList();
    Map<UUID, Instant> resultado = new HashMap<>();
    for (Recordatorio r : recordatorios.findByControlIdInOrderByEnviadoEnDesc(ids)) {
      if (r.getTipo() == tipo) {
        resultado.putIfAbsent(r.getControlId(), r.getEnviadoEn());
      }
    }
    return resultado;
  }
}
