package pe.gerenzdent.tratamiento.application;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.shared.domain.Textos;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;
import pe.gerenzdent.tratamiento.infrastructure.TratamientoRepository;

/** Catálogo de tratamientos (HU-08, HU-10). */
@Service
public class TratamientoService {

  private final TratamientoRepository tratamientos;

  public TratamientoService(TratamientoRepository tratamientos) {
    this.tratamientos = tratamientos;
  }

  public record DatosTratamiento(
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {}

  /** Solo activos (al agendar) o todos (pantalla del catálogo). */
  @Transactional(readOnly = true)
  public List<Tratamiento> listar(boolean incluirInactivos) {
    return incluirInactivos
        ? tratamientos.findAllByOrderByActivoDescOrdenAscNombreAsc()
        : tratamientos.findByActivoTrueOrderByOrdenAscNombreAsc();
  }

  @Transactional
  public Tratamiento crear(DatosTratamiento d) {
    String nombre = Textos.limpiar(d.nombre());
    if (nombre != null && tratamientos.existsByNombreIgnoreCase(nombre)) {
      throw duplicado(nombre);
    }
    Tratamiento t =
        new Tratamiento(
            d.nombre(),
            d.tipoPrecio(),
            d.precioBase(),
            d.precioMensual(),
            d.intervaloControlDias(),
            d.edadMaximaControl());
    t.ubicarAlFinal(tratamientos.ordenMaximo() + 1);
    return tratamientos.saveAndFlush(t);
  }

  @Transactional
  public Tratamiento actualizar(UUID id, DatosTratamiento d) {
    Tratamiento t = obtener(id);
    String nombre = Textos.limpiar(d.nombre());
    if (nombre != null && tratamientos.existsByNombreIgnoreCaseAndIdNot(nombre, id)) {
      throw duplicado(nombre);
    }
    t.actualizar(
        d.nombre(),
        d.tipoPrecio(),
        d.precioBase(),
        d.precioMensual(),
        d.intervaloControlDias(),
        d.edadMaximaControl());
    return tratamientos.saveAndFlush(t);
  }

  @Transactional
  public Tratamiento cambiarActivo(UUID id, boolean activo) {
    Tratamiento t = obtener(id);
    t.cambiarActivo(activo);
    return tratamientos.saveAndFlush(t);
  }

  private Tratamiento obtener(UUID id) {
    return tratamientos
        .findById(id)
        .orElseThrow(() -> new RecursoNoEncontrado("Tratamiento no encontrado."));
  }

  private static Conflicto duplicado(String nombre) {
    return new Conflicto("Ya existe un tratamiento llamado \"%s\".".formatted(nombre), Map.of());
  }
}
