package pe.gerenzdent.control;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.control.domain.EstadoControl;
import pe.gerenzdent.control.domain.PlanTratamiento;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

class ControlTest {

  private static final LocalDate HOY = LocalDate.of(2026, 11, 10);

  private static final Tratamiento BRACKETS =
      new Tratamiento(
          "Brackets",
          TipoPrecio.INICIAL_MAS_MENSUAL,
          new BigDecimal("500"),
          BigDecimal.TEN,
          30,
          null);
  private static final Tratamiento PUENTE =
      new Tratamiento("Puente", TipoPrecio.POR_PIEZA, new BigDecimal("700"), null, null, null);

  private final PlanTratamiento plan = new PlanTratamiento(UUID.randomUUID(), BRACKETS, null, HOY);

  @Test
  void nuevoControlEmpiezaPendienteYSinSegundos() {
    Control c = new Control(plan, HOY, LocalTime.of(19, 30, 45), "  traer radiografía ", HOY);

    assertThat(c.getEstado()).isEqualTo(EstadoControl.PENDIENTE);
    assertThat(c.getHora()).isEqualTo(LocalTime.of(19, 30));
    assertThat(c.getNota()).isEqualTo("traer radiografía");
  }

  @Test
  void noPermiteFechasPasadas() {
    assertThatThrownBy(() -> new Control(plan, HOY.minusDays(1), null, null, HOY))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("fecha");
  }

  @Test
  void rechazaNotaLarga() {
    assertThatThrownBy(() -> new Control(plan, HOY, null, "x".repeat(141), HOY))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("nota");
  }

  @Test
  void transicionInvalidaEsConflicto() {
    Control c = new Control(plan, HOY, null, null, HOY);
    c.cambiarEstado(EstadoControl.ASISTIO, HOY);

    assertThatThrownBy(() -> c.cambiarEstado(EstadoControl.CANCELADO, HOY))
        .isInstanceOf(Conflicto.class)
        .hasMessageContaining("asistió");
  }

  @Test
  void reprogramarVuelveAPendiente() {
    Control c = new Control(plan, HOY, null, null, HOY);
    c.cambiarEstado(EstadoControl.CONFIRMADO, HOY);

    c.reprogramar(HOY.plusDays(3), LocalTime.of(18, 0), HOY);

    assertThat(c.getEstado()).isEqualTo(EstadoControl.PENDIENTE);
    assertThat(c.getFecha()).isEqualTo(HOY.plusDays(3));
  }

  @Test
  void noSeReprogramaUnControlCerrado() {
    Control c = new Control(plan, HOY, null, null, HOY);
    c.cambiarEstado(EstadoControl.CANCELADO, HOY);

    assertThatThrownBy(() -> c.reprogramar(HOY.plusDays(1), null, HOY))
        .isInstanceOf(Conflicto.class);
  }

  @Test
  void vencidoEsAbiertoConFechaPasada() {
    Control c = new Control(plan, HOY, null, null, HOY);
    LocalDate cuatroDiasDespues = HOY.plusDays(4);

    assertThat(c.estaVencido(HOY)).isFalse();
    assertThat(c.estaVencido(cuatroDiasDespues)).isTrue();
    assertThat(c.diasDeAtraso(cuatroDiasDespues)).isEqualTo(4);

    c.cambiarEstado(EstadoControl.ASISTIO, HOY);
    assertThat(c.estaVencido(cuatroDiasDespues)).isFalse();
    assertThat(c.diasDeAtraso(cuatroDiasDespues)).isZero();
  }

  @Test
  void soloLosTratamientosPorPiezaGuardanPiezas() {
    assertThat(new PlanTratamiento(UUID.randomUUID(), BRACKETS, 3, HOY).getPiezas()).isNull();
    assertThat(new PlanTratamiento(UUID.randomUUID(), PUENTE, null, HOY).getPiezas()).isEqualTo(1);
    assertThat(new PlanTratamiento(UUID.randomUUID(), PUENTE, 2, HOY).getPiezas()).isEqualTo(2);
    assertThatThrownBy(() -> new PlanTratamiento(UUID.randomUUID(), PUENTE, 0, HOY))
        .isInstanceOf(DatoInvalido.class);
  }

  @Test
  void alCerrarseGuardaElDiaRealYNoLaFechaPlanificada() {
    Control c = new Control(plan, HOY.plusDays(10), null, null, HOY);

    c.cambiarEstado(EstadoControl.ASISTIO, HOY.plusDays(2)); // vino 8 días antes

    assertThat(c.getFecha()).isEqualTo(HOY.plusDays(10));
    assertThat(c.getCerradoEn()).isEqualTo(HOY.plusDays(2));
  }

  @Test
  void registrarRecordatorioPasaDePendienteARecordado() {
    Control c = new Control(plan, HOY, null, null, HOY);
    c.registrarRecordatorio();
    assertThat(c.getEstado()).isEqualTo(EstadoControl.RECORDADO);
    assertThat(c.getCerradoEn()).isNull();

    c.cambiarEstado(EstadoControl.CONFIRMADO, HOY);
    c.registrarRecordatorio(); // seguimiento: un confirmado sigue confirmado
    assertThat(c.getEstado()).isEqualTo(EstadoControl.CONFIRMADO);

    c.cambiarEstado(EstadoControl.CANCELADO, HOY);
    assertThatThrownBy(c::registrarRecordatorio).isInstanceOf(Conflicto.class);
  }
}
