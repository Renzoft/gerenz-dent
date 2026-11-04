package pe.gerenzdent.cuenta.application;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import pe.gerenzdent.control.domain.EventosControl.ControlAsistido;
import pe.gerenzdent.control.domain.EventosControl.PlanCreado;
import pe.gerenzdent.control.domain.PlanTratamiento;
import pe.gerenzdent.control.infrastructure.PlanTratamientoRepository;
import pe.gerenzdent.cuenta.domain.Cargo;
import pe.gerenzdent.cuenta.domain.EstadoMovimiento;
import pe.gerenzdent.cuenta.domain.Montos;
import pe.gerenzdent.cuenta.domain.Movimientos;
import pe.gerenzdent.cuenta.domain.Pago;
import pe.gerenzdent.cuenta.infrastructure.CargoRepository;
import pe.gerenzdent.cuenta.infrastructure.PagoRepository;
import pe.gerenzdent.paciente.application.PacienteService;
import pe.gerenzdent.paciente.domain.Paciente;
import pe.gerenzdent.paciente.infrastructure.PacienteRepository;
import pe.gerenzdent.shared.config.Calendario;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

/** Deudas y pagos (HU-21 a HU-25). Deuda = Σ cargos válidos − Σ pagos válidos. */
@Service
public class CuentaService {

  private final CargoRepository cargos;
  private final PagoRepository pagos;
  private final PlanTratamientoRepository planes;
  private final PacienteService pacienteService;
  private final PacienteRepository pacientes;
  private final Calendario calendario;

  public CuentaService(
      CargoRepository cargos,
      PagoRepository pagos,
      PlanTratamientoRepository planes,
      PacienteService pacienteService,
      PacienteRepository pacientes,
      Calendario calendario) {
    this.cargos = cargos;
    this.pagos = pagos;
    this.planes = planes;
    this.pacienteService = pacienteService;
    this.pacientes = pacientes;
    this.calendario = calendario;
  }

  /** Movimientos y saldo de un plan. */
  public record CuentaPlan(
      PlanTratamiento plan,
      List<Cargo> cargos,
      List<Pago> pagos,
      BigDecimal totalCargos,
      BigDecimal totalPagos,
      BigDecimal saldo) {}

  public record CuentaPaciente(BigDecimal deuda, List<CuentaPlan> planes) {}

  public record DeudaPaciente(Paciente paciente, BigDecimal deuda) {}

  public record ResumenDeudas(BigDecimal total, List<DeudaPaciente> pacientes) {}

  // ---------------------------------------------------------------------------------------------
  // Cargos automáticos (eventos del módulo de controles)
  // ---------------------------------------------------------------------------------------------

  /**
   * Plan nuevo: cargo según el catálogo (fijo, por pieza o inicial), o el monto que acordó el
   * doctor. Si el paciente pagó algo al registrarse, también se guarda.
   */
  @EventListener
  public void alCrearPlan(PlanCreado evento) {
    PlanTratamiento plan = evento.plan();
    Tratamiento t = plan.getTratamiento();
    BigDecimal monto =
        evento.costoAcordado() != null ? evento.costoAcordado() : precioDeCatalogo(plan);
    if (monto != null) {
      Cargo.Concepto concepto =
          t.getTipoPrecio() == TipoPrecio.INICIAL_MAS_MENSUAL
              ? Cargo.Concepto.INICIAL
              : Cargo.Concepto.TRATAMIENTO;
      cargos.save(new Cargo(plan.getId(), null, concepto, null, monto, evento.fecha()));
    }
    if (evento.pagoInicial() != null) {
      registrarPagoEnPlan(
          plan,
          evento.pagoInicial(),
          evento.fecha(),
          medio(evento.medioPagoInicial()),
          null,
          "pagoInicial");
    }
  }

  /** Brackets: al asistir se carga la cuota mensual, una sola vez por control (RN-06). */
  @EventListener
  public void alAsistir(ControlAsistido evento) {
    PlanTratamiento plan = evento.control().getPlan();
    Tratamiento t = plan.getTratamiento();
    if (t.getTipoPrecio() != TipoPrecio.INICIAL_MAS_MENSUAL || t.getPrecioMensual() == null) {
      return;
    }
    UUID controlId = evento.control().getId();
    if (cargos.existsByControlIdAndEstado(controlId, EstadoMovimiento.VALIDO)) {
      return;
    }
    cargos.save(
        new Cargo(
            plan.getId(),
            controlId,
            Cargo.Concepto.MENSUAL,
            null,
            t.getPrecioMensual(),
            evento.fecha()));
  }

  static BigDecimal precioDeCatalogo(PlanTratamiento plan) {
    Tratamiento t = plan.getTratamiento();
    if (t.getPrecioBase() == null) {
      return null;
    }
    if (t.getTipoPrecio() == TipoPrecio.POR_PIEZA) {
      int piezas = plan.getPiezas() == null ? 1 : plan.getPiezas();
      return t.getPrecioBase().multiply(BigDecimal.valueOf(piezas));
    }
    return t.getPrecioBase();
  }

  // ---------------------------------------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------------------------------------

  /** Cuenta del paciente: sus planes con cargos, pagos y saldo (ficha, HU-23/HU-24). */
  @Transactional(readOnly = true)
  public CuentaPaciente cuentaDePaciente(UUID usuarioId, UUID pacienteId) {
    pacienteService.obtener(usuarioId, pacienteId); // verifica que es del usuario
    List<PlanTratamiento> lista = planes.findByPacienteIdOrderByFechaInicioDesc(pacienteId);
    List<UUID> ids = lista.stream().map(PlanTratamiento::getId).toList();
    Map<UUID, List<Cargo>> cargosPorPlan = new HashMap<>();
    Map<UUID, List<Pago>> pagosPorPlan = new HashMap<>();
    if (!ids.isEmpty()) {
      for (Cargo c : cargos.findByPlanIdInOrderByFechaAscCreatedAtAsc(ids)) {
        cargosPorPlan.computeIfAbsent(c.getPlanId(), k -> new ArrayList<>()).add(c);
      }
      for (Pago p : pagos.findByPlanIdInOrderByFechaAscCreatedAtAsc(ids)) {
        pagosPorPlan.computeIfAbsent(p.getPlanId(), k -> new ArrayList<>()).add(p);
      }
    }
    List<CuentaPlan> cuentas =
        lista.stream()
            .map(plan ->
                cuentaPlan(
                    plan,
                    cargosPorPlan.getOrDefault(plan.getId(), List.of()),
                    pagosPorPlan.getOrDefault(plan.getId(), List.of())))
            .toList();
    BigDecimal deuda =
        cuentas.stream().map(CuentaPlan::saldo).reduce(Montos.cero(), BigDecimal::add);
    return new CuentaPaciente(deuda, cuentas);
  }

  /** Pacientes con deuda (incluye archivados, RN-05), de mayor a menor (HU-23). */
  @Transactional(readOnly = true)
  public ResumenDeudas deudas(UUID usuarioId) {
    Map<UUID, BigDecimal> saldo = new HashMap<>();
    for (Object[] fila : cargos.totalesPorPaciente(usuarioId)) {
      saldo.merge((UUID) fila[0], (BigDecimal) fila[1], BigDecimal::add);
    }
    for (Object[] fila : pagos.totalesPorPaciente(usuarioId)) {
      saldo.merge((UUID) fila[0], ((BigDecimal) fila[1]).negate(), BigDecimal::add);
    }
    Map<UUID, BigDecimal> conDeuda = new HashMap<>();
    saldo.forEach((id, valor) -> {
      if (valor.signum() > 0) {
        conDeuda.put(id, valor.setScale(2));
      }
    });
    List<DeudaPaciente> lista =
        pacientes.findAllById(conDeuda.keySet()).stream()
            .map(p -> new DeudaPaciente(p, conDeuda.get(p.getId())))
            .sorted(
                Comparator.comparing(DeudaPaciente::deuda)
                    .reversed()
                    .thenComparing(d -> d.paciente().getNombre()))
            .toList();
    BigDecimal total =
        lista.stream().map(DeudaPaciente::deuda).reduce(Montos.cero(), BigDecimal::add);
    return new ResumenDeudas(total, lista);
  }

  // ---------------------------------------------------------------------------------------------
  // Pagos y ajustes
  // ---------------------------------------------------------------------------------------------

  /** Registra un abono (HU-22). No puede dejar el saldo del plan en negativo. */
  @Transactional
  public CuentaPlan registrarPago(
      UUID usuarioId,
      UUID planId,
      BigDecimal monto,
      LocalDate fecha,
      Pago.Medio medio,
      String nota) {
    PlanTratamiento plan = planDelUsuario(usuarioId, planId);
    registrarPagoEnPlan(
        plan, monto, fecha == null ? calendario.hoy() : fecha, medio, nota, "monto");
    return cuentaPlan(plan);
  }

  @Transactional
  public CuentaPlan anularPago(UUID usuarioId, UUID pagoId, String motivo) {
    Pago pago = pagos.findById(pagoId).orElseThrow(() -> noEncontrado("Pago"));
    PlanTratamiento plan = planDelUsuario(usuarioId, pago.getPlanId());
    pago.anular(motivo);
    pagos.saveAndFlush(pago);
    return cuentaPlan(plan);
  }

  /** Cargo manual (material adicional, otro procedimiento…). */
  @Transactional
  public CuentaPlan agregarCargo(
      UUID usuarioId, UUID planId, String descripcion, BigDecimal monto) {
    PlanTratamiento plan = planDelUsuario(usuarioId, planId);
    cargos.save(
        new Cargo(plan.getId(), null, Cargo.Concepto.OTRO, descripcion, monto, calendario.hoy()));
    return cuentaPlan(plan);
  }

  /** Descuento o corrección (RN-08). El nuevo monto no puede quedar por debajo de lo ya pagado. */
  @Transactional
  public CuentaPlan ajustarCargo(UUID usuarioId, UUID cargoId, BigDecimal nuevoMonto) {
    Cargo cargo = cargos.findById(cargoId).orElseThrow(() -> noEncontrado("Cargo"));
    PlanTratamiento plan = planDelUsuario(usuarioId, cargo.getPlanId());
    BigDecimal diferencia = Montos.validar(nuevoMonto, "monto", true).subtract(cargo.getMonto());
    exigirSaldoNoNegativo(plan, diferencia, "monto");
    cargo.ajustarMonto(nuevoMonto);
    cargos.saveAndFlush(cargo);
    return cuentaPlan(plan);
  }

  @Transactional
  public CuentaPlan anularCargo(UUID usuarioId, UUID cargoId, String motivo) {
    Cargo cargo = cargos.findById(cargoId).orElseThrow(() -> noEncontrado("Cargo"));
    PlanTratamiento plan = planDelUsuario(usuarioId, cargo.getPlanId());
    if (cargo.esValido()) {
      exigirSaldoNoNegativo(plan, cargo.getMonto().negate(), "monto");
    }
    cargo.anular(motivo);
    cargos.saveAndFlush(cargo);
    return cuentaPlan(plan);
  }

  // ---------------------------------------------------------------------------------------------

  private void registrarPagoEnPlan(
      PlanTratamiento plan,
      BigDecimal monto,
      LocalDate fecha,
      Pago.Medio medio,
      String nota,
      String campo) {
    Pago pago = new Pago(plan.getId(), monto, fecha, medio, nota, calendario.hoy());
    BigDecimal saldo = saldoDe(plan);
    if (pago.getMonto().compareTo(saldo) > 0) {
      throw new DatoInvalido(
          campo,
          saldo.signum() <= 0
              ? "Este tratamiento no tiene deuda pendiente."
              : "El pago supera la deuda de S/ %s.".formatted(saldo.toPlainString()));
    }
    pagos.saveAndFlush(pago);
  }

  /** {@code cambio} &lt; 0 reduce los cargos: no puede quedar menos de lo ya pagado. */
  private void exigirSaldoNoNegativo(PlanTratamiento plan, BigDecimal cambio, String campo) {
    if (saldoDe(plan).add(cambio).signum() < 0) {
      throw new DatoInvalido(
          campo, "El paciente ya pagó más que eso. Anula primero el pago que sobra.");
    }
  }

  private BigDecimal saldoDe(PlanTratamiento plan) {
    return cuentaPlan(plan).saldo();
  }

  private CuentaPlan cuentaPlan(PlanTratamiento plan) {
    List<UUID> id = List.of(plan.getId());
    return cuentaPlan(
        plan,
        cargos.findByPlanIdInOrderByFechaAscCreatedAtAsc(id),
        pagos.findByPlanIdInOrderByFechaAscCreatedAtAsc(id));
  }

  private static CuentaPlan cuentaPlan(PlanTratamiento plan, List<Cargo> cs, List<Pago> ps) {
    return new CuentaPlan(
        plan,
        cs,
        ps,
        Movimientos.totalCargos(cs),
        Movimientos.totalPagos(ps),
        Movimientos.saldo(cs, ps));
  }

  private PlanTratamiento planDelUsuario(UUID usuarioId, UUID planId) {
    PlanTratamiento plan =
        planes.findConTratamientoById(planId).orElseThrow(() -> noEncontrado("Tratamiento"));
    pacienteService.obtener(usuarioId, plan.getPacienteId()); // 404 si no es suyo
    return plan;
  }

  private static Pago.Medio medio(String nombre) {
    if (nombre == null || nombre.isBlank()) {
      return Pago.Medio.EFECTIVO;
    }
    try {
      return Pago.Medio.valueOf(nombre.strip().toUpperCase(java.util.Locale.ROOT));
    } catch (IllegalArgumentException e) {
      throw new DatoInvalido("medioPago", "Medio de pago no válido.");
    }
  }

  private static RecursoNoEncontrado noEncontrado(String que) {
    return new RecursoNoEncontrado(que + " no encontrado.");
  }
}
