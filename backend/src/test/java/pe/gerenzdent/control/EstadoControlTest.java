package pe.gerenzdent.control;

import static org.assertj.core.api.Assertions.assertThat;
import static pe.gerenzdent.control.domain.EstadoControl.ASISTIO;
import static pe.gerenzdent.control.domain.EstadoControl.CANCELADO;
import static pe.gerenzdent.control.domain.EstadoControl.CONFIRMADO;
import static pe.gerenzdent.control.domain.EstadoControl.NO_ASISTIO;
import static pe.gerenzdent.control.domain.EstadoControl.PENDIENTE;
import static pe.gerenzdent.control.domain.EstadoControl.RECORDADO;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.EnumSource;
import pe.gerenzdent.control.domain.EstadoControl;

class EstadoControlTest {

  @ParameterizedTest(name = "{0} → {1}: {2}")
  @CsvSource({
    "PENDIENTE, RECORDADO, true",
    "PENDIENTE, CONFIRMADO, true",
    "PENDIENTE, ASISTIO, true",
    "PENDIENTE, NO_ASISTIO, true",
    "PENDIENTE, CANCELADO, true",
    "PENDIENTE, PENDIENTE, false",
    "RECORDADO, RECORDADO, true",
    "RECORDADO, CONFIRMADO, true",
    "RECORDADO, ASISTIO, true",
    "CONFIRMADO, ASISTIO, true",
    "CONFIRMADO, NO_ASISTIO, true",
    "CONFIRMADO, CONFIRMADO, false",
    "CONFIRMADO, RECORDADO, false"
  })
  void transicionesDesdeEstadosAbiertos(
      EstadoControl origen, EstadoControl destino, boolean permitida) {
    assertThat(origen.puedePasarA(destino)).isEqualTo(permitida);
  }

  @ParameterizedTest
  @EnumSource(
      value = EstadoControl.class,
      names = {"ASISTIO", "NO_ASISTIO", "CANCELADO"})
  void losEstadosFinalesNoCambian(EstadoControl finalizado) {
    assertThat(finalizado.esAbierto()).isFalse();
    for (EstadoControl destino : EstadoControl.values()) {
      assertThat(finalizado.puedePasarA(destino)).isFalse();
    }
  }

  @ParameterizedTest
  @EnumSource(
      value = EstadoControl.class,
      names = {"PENDIENTE", "RECORDADO", "CONFIRMADO"})
  void abiertos(EstadoControl estado) {
    assertThat(estado.esAbierto()).isTrue();
    assertThat(EstadoControl.abiertos()).contains(estado);
    assertThat(EstadoControl.abiertos())
        .doesNotContain(ASISTIO, NO_ASISTIO, CANCELADO)
        .contains(PENDIENTE, RECORDADO, CONFIRMADO);
  }
}
