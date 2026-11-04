package pe.gerenzdent.tratamiento.api;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;
import pe.gerenzdent.tratamiento.infrastructure.TratamientoRepository;

/** Catálogo de tratamientos activos (HU-08). La edición del catálogo llega en la iteración 5. */
@RestController
@RequestMapping("/api/v1/tratamientos")
public class TratamientoController {

  private final TratamientoRepository tratamientos;

  public TratamientoController(TratamientoRepository tratamientos) {
    this.tratamientos = tratamientos;
  }

  public record TratamientoResponse(
      UUID id,
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {

    public static TratamientoResponse de(Tratamiento t) {
      return new TratamientoResponse(
          t.getId(),
          t.getNombre(),
          t.getTipoPrecio(),
          t.getPrecioBase(),
          t.getPrecioMensual(),
          t.getIntervaloControlDias(),
          t.getEdadMaximaControl());
    }
  }

  @GetMapping
  @Transactional(readOnly = true)
  public List<TratamientoResponse> listar() {
    return tratamientos.findByActivoTrueOrderByOrdenAscNombreAsc().stream()
        .map(TratamientoResponse::de)
        .toList();
  }
}
