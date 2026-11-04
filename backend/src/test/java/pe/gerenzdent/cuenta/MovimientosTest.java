package pe.gerenzdent.cuenta;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.cuenta.domain.Cargo;
import pe.gerenzdent.cuenta.domain.Montos;
import pe.gerenzdent.cuenta.domain.Movimientos;
import pe.gerenzdent.cuenta.domain.Pago;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

class MovimientosTest {

  private static final LocalDate HOY = LocalDate.of(2026, 11, 10);
  private static final UUID PLAN = UUID.randomUUID();

  private static Cargo cargo(String monto) {
    return new Cargo(PLAN, null, Cargo.Concepto.TRATAMIENTO, null, new BigDecimal(monto), HOY);
  }

  private static Pago pago(String monto) {
    return new Pago(PLAN, new BigDecimal(monto), HOY, Pago.Medio.YAPE, null, HOY);
  }

  @Test
  void saldoEsCargosMenosPagosValidos() {
    Cargo inicial = cargo("500");
    Cargo cuota = cargo("100");
    Pago abono = pago("300");
    Pago errado = pago("50");
    errado.anular("Registrado dos veces");

    assertThat(Movimientos.saldo(List.of(inicial, cuota), List.of(abono, errado)))
        .isEqualByComparingTo("300.00");
  }

  @Test
  void unCargoAnuladoNoSuma() {
    Cargo cuota = cargo("100");
    cuota.anular("No se cobró este mes");

    assertThat(Movimientos.totalCargos(List.of(cargo("500"), cuota)))
        .isEqualByComparingTo("500.00");
  }

  @Test
  void ajustarMontoAplicaElDescuento() {
    Cargo c = cargo("1000");
    c.ajustarMonto(new BigDecimal("850.5"));
    assertThat(c.getMonto()).isEqualByComparingTo("850.50");
  }

  @Test
  void noSeAnulaDosVecesNiSeAjustaUnAnulado() {
    Cargo c = cargo("100");
    c.anular("Error");
    assertThatThrownBy(() -> c.anular("Otra vez")).isInstanceOf(Conflicto.class);
    assertThatThrownBy(() -> c.ajustarMonto(BigDecimal.ONE)).isInstanceOf(Conflicto.class);
  }

  @Test
  void anularExigeMotivo() {
    assertThatThrownBy(() -> pago("10").anular("   "))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("motivo");
  }

  @Test
  void elPagoNoPuedeSerCeroNiFuturo() {
    assertThatThrownBy(() -> pago("0")).isInstanceOf(DatoInvalido.class);
    assertThatThrownBy(() -> new Pago(PLAN, BigDecimal.TEN, HOY.plusDays(1), null, null, HOY))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("fecha");
  }

  @Test
  void sinMedioSeAsumeEfectivo() {
    assertThat(new Pago(PLAN, BigDecimal.TEN, HOY, null, null, HOY).getMedio())
        .isEqualTo(Pago.Medio.EFECTIVO);
  }

  @Test
  void unCargoPuedeSerCeroPeroNoNegativo() {
    assertThat(cargo("0").getMonto()).isEqualByComparingTo("0");
    assertThatThrownBy(() -> cargo("-1")).isInstanceOf(DatoInvalido.class);
  }

  @Test
  void elCargoManualNecesitaDescripcion() {
    assertThatThrownBy(() -> new Cargo(PLAN, null, Cargo.Concepto.OTRO, " ", BigDecimal.TEN, HOY))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("descripcion");
  }

  @Test
  void montosSeRedondeanACentimosYTienenTope() {
    assertThat(Montos.validar(new BigDecimal("10.005"), "monto", false))
        .isEqualByComparingTo("10.01");
    assertThatThrownBy(() -> Montos.validar(new BigDecimal("100000"), "monto", false))
        .isInstanceOf(DatoInvalido.class);
  }
}
