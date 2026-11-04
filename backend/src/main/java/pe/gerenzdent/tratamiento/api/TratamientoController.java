package pe.gerenzdent.tratamiento.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.tratamiento.application.TratamientoService;
import pe.gerenzdent.tratamiento.application.TratamientoService.DatosTratamiento;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

/** Catálogo de tratamientos (HU-08) y su edición (HU-10). */
@RestController
@RequestMapping("/api/v1/tratamientos")
public class TratamientoController {

  private final TratamientoService servicio;

  public TratamientoController(TratamientoService servicio) {
    this.servicio = servicio;
  }

  public record TratamientoRequest(
      @NotBlank(message = "Ingresa el nombre") @Size(max = 80, message = "Máximo 80 caracteres")
          String nombre,
      @NotNull(message = "Elige cómo se cobra") TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl) {

    DatosTratamiento aDatos() {
      return new DatosTratamiento(
          nombre, tipoPrecio, precioBase, precioMensual, intervaloControlDias, edadMaximaControl);
    }
  }

  public record ActivoRequest(@NotNull Boolean activo) {}

  public record TratamientoResponse(
      UUID id,
      String nombre,
      TipoPrecio tipoPrecio,
      BigDecimal precioBase,
      BigDecimal precioMensual,
      Integer intervaloControlDias,
      Integer edadMaximaControl,
      boolean activo) {

    public static TratamientoResponse de(Tratamiento t) {
      return new TratamientoResponse(
          t.getId(),
          t.getNombre(),
          t.getTipoPrecio(),
          t.getPrecioBase(),
          t.getPrecioMensual(),
          t.getIntervaloControlDias(),
          t.getEdadMaximaControl(),
          t.isActivo());
    }
  }

  /** Por defecto solo los activos (para agendar); {@code ?todos=true} para editar el catálogo. */
  @GetMapping
  public List<TratamientoResponse> listar(@RequestParam(defaultValue = "false") boolean todos) {
    return servicio.listar(todos).stream().map(TratamientoResponse::de).toList();
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public TratamientoResponse crear(@Valid @RequestBody TratamientoRequest r) {
    return TratamientoResponse.de(servicio.crear(r.aDatos()));
  }

  @PutMapping("/{id}")
  public TratamientoResponse actualizar(
      @PathVariable UUID id, @Valid @RequestBody TratamientoRequest r) {
    return TratamientoResponse.de(servicio.actualizar(id, r.aDatos()));
  }

  @PatchMapping("/{id}/activo")
  public TratamientoResponse cambiarActivo(
      @PathVariable UUID id, @Valid @RequestBody ActivoRequest r) {
    return TratamientoResponse.de(servicio.cambiarActivo(id, r.activo()));
  }
}
