package pe.gerenzdent.cuenta.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import pe.gerenzdent.control.domain.PlanTratamiento;
import pe.gerenzdent.cuenta.application.CuentaService;
import pe.gerenzdent.cuenta.application.CuentaService.CuentaPlan;
import pe.gerenzdent.cuenta.domain.Cargo;
import pe.gerenzdent.cuenta.domain.EstadoMovimiento;
import pe.gerenzdent.cuenta.domain.Pago;
import pe.gerenzdent.shared.api.UsuarioAutenticado;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;

/** Deudas y pagos (HU-21 a HU-25). */
@RestController
@RequestMapping("/api/v1")
public class CuentaController {

  private final CuentaService servicio;

  public CuentaController(CuentaService servicio) {
    this.servicio = servicio;
  }

  // ----- Contratos JSON -----

  public record PagoRequest(
      @NotNull(message = "Ingresa el monto")
          @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0")
          BigDecimal monto,
      LocalDate fecha,
      Pago.Medio medio,
      @Size(max = Pago.NOTA_MAX, message = "Máximo 140 caracteres") String nota) {}

  public record CargoRequest(
      @NotBlank(message = "Describe el cargo") @Size(max = 80, message = "Máximo 80 caracteres")
          String descripcion,
      @NotNull(message = "Ingresa el monto")
          @DecimalMin(value = "0.00", message = "El monto no puede ser negativo")
          BigDecimal monto) {}

  public record AjusteRequest(
      @NotNull(message = "Ingresa el monto")
          @DecimalMin(value = "0.00", message = "El monto no puede ser negativo")
          BigDecimal monto) {}

  public record AnulacionRequest(
      @NotBlank(message = "Indica el motivo") @Size(max = 140, message = "Máximo 140 caracteres")
          String motivo) {}

  public record CargoResponse(
      UUID id,
      Cargo.Concepto concepto,
      String descripcion,
      BigDecimal monto,
      LocalDate fecha,
      EstadoMovimiento estado,
      String motivoAnulacion,
      UUID controlId) {
    static CargoResponse de(Cargo c) {
      return new CargoResponse(
          c.getId(),
          c.getConcepto(),
          c.getDescripcion(),
          c.getMonto(),
          c.getFecha(),
          c.getEstado(),
          c.getMotivoAnulacion(),
          c.getControlId());
    }
  }

  public record PagoResponse(
      UUID id,
      BigDecimal monto,
      LocalDate fecha,
      Pago.Medio medio,
      String nota,
      EstadoMovimiento estado,
      String motivoAnulacion) {
    static PagoResponse de(Pago p) {
      return new PagoResponse(
          p.getId(),
          p.getMonto(),
          p.getFecha(),
          p.getMedio(),
          p.getNota(),
          p.getEstado(),
          p.getMotivoAnulacion());
    }
  }

  public record TratamientoResumen(UUID id, String nombre, TipoPrecio tipoPrecio) {}

  public record CuentaPlanResponse(
      UUID planId,
      UUID pacienteId,
      TratamientoResumen tratamiento,
      Integer piezas,
      PlanTratamiento.Estado estado,
      LocalDate fechaInicio,
      BigDecimal totalCargos,
      BigDecimal totalPagos,
      BigDecimal saldo,
      List<CargoResponse> cargos,
      List<PagoResponse> pagos) {
    static CuentaPlanResponse de(CuentaPlan c) {
      PlanTratamiento p = c.plan();
      return new CuentaPlanResponse(
          p.getId(),
          p.getPacienteId(),
          new TratamientoResumen(
              p.getTratamiento().getId(),
              p.getTratamiento().getNombre(),
              p.getTratamiento().getTipoPrecio()),
          p.getPiezas(),
          p.getEstado(),
          p.getFechaInicio(),
          c.totalCargos(),
          c.totalPagos(),
          c.saldo(),
          c.cargos().stream().map(CargoResponse::de).toList(),
          c.pagos().stream().map(PagoResponse::de).toList());
    }
  }

  public record CuentaPacienteResponse(BigDecimal deuda, List<CuentaPlanResponse> planes) {}

  public record DeudaPacienteResponse(
      UUID pacienteId, String nombre, String whatsapp, boolean archivado, BigDecimal deuda) {}

  public record DeudasResponse(
      BigDecimal total, int cantidadPacientes, List<DeudaPacienteResponse> pacientes) {}

  // ----- Endpoints -----

  /** Cuenta del paciente: tratamientos con cargos, pagos y saldo (ficha). */
  @GetMapping("/pacientes/{pacienteId}/cuenta")
  public CuentaPacienteResponse cuenta(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID pacienteId) {
    var cuenta = servicio.cuentaDePaciente(UsuarioAutenticado.id(jwt), pacienteId);
    return new CuentaPacienteResponse(
        cuenta.deuda(), cuenta.planes().stream().map(CuentaPlanResponse::de).toList());
  }

  /** Pacientes con deuda y total que se le debe al consultorio (pestaña Deudas). */
  @GetMapping("/deudas")
  public DeudasResponse deudas(@AuthenticationPrincipal Jwt jwt) {
    var resumen = servicio.deudas(UsuarioAutenticado.id(jwt));
    return new DeudasResponse(
        resumen.total(),
        resumen.pacientes().size(),
        resumen.pacientes().stream()
            .map(d ->
                new DeudaPacienteResponse(
                    d.paciente().getId(),
                    d.paciente().getNombre(),
                    d.paciente().getWhatsapp(),
                    d.paciente().isArchivado(),
                    d.deuda()))
            .toList());
  }

  @PostMapping("/planes/{planId}/pagos")
  @ResponseStatus(HttpStatus.CREATED)
  public CuentaPlanResponse registrarPago(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID planId,
      @Valid @RequestBody PagoRequest r) {
    return CuentaPlanResponse.de(
        servicio.registrarPago(
            UsuarioAutenticado.id(jwt), planId, r.monto(), r.fecha(), r.medio(), r.nota()));
  }

  @PatchMapping("/pagos/{pagoId}/anular")
  public CuentaPlanResponse anularPago(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID pagoId,
      @Valid @RequestBody AnulacionRequest r) {
    return CuentaPlanResponse.de(
        servicio.anularPago(UsuarioAutenticado.id(jwt), pagoId, r.motivo()));
  }

  @PostMapping("/planes/{planId}/cargos")
  @ResponseStatus(HttpStatus.CREATED)
  public CuentaPlanResponse agregarCargo(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID planId,
      @Valid @RequestBody CargoRequest r) {
    return CuentaPlanResponse.de(
        servicio.agregarCargo(UsuarioAutenticado.id(jwt), planId, r.descripcion(), r.monto()));
  }

  /** Ajustar el monto de un cargo (descuento). */
  @PatchMapping("/cargos/{cargoId}")
  public CuentaPlanResponse ajustarCargo(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID cargoId,
      @Valid @RequestBody AjusteRequest r) {
    return CuentaPlanResponse.de(
        servicio.ajustarCargo(UsuarioAutenticado.id(jwt), cargoId, r.monto()));
  }

  @PatchMapping("/cargos/{cargoId}/anular")
  public CuentaPlanResponse anularCargo(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID cargoId,
      @Valid @RequestBody AnulacionRequest r) {
    return CuentaPlanResponse.de(
        servicio.anularCargo(UsuarioAutenticado.id(jwt), cargoId, r.motivo()));
  }
}
