package pe.gerenzdent.tratamiento;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import pe.gerenzdent.tratamiento.domain.TipoPrecio;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

class TratamientoTest {

  private static final LocalDate HOY = LocalDate.of(2026, 11, 10);

  private static Tratamiento con(Integer intervalo, Integer edadMaxima) {
    return new Tratamiento("X", TipoPrecio.FIJO, BigDecimal.ONE, null, intervalo, edadMaxima);
  }

  @Test
  void sinIntervaloNoHaySugerencia() {
    assertThat(con(null, null).fechaSugerida(HOY, 30)).isEmpty();
  }

  @Test
  void bracketsSugiereUnMesDespues() {
    assertThat(con(30, null).fechaSugerida(HOY, null)).contains(HOY.plusDays(30));
  }

  @Test
  void fluorSoloSeSugiereHastaLos12Anios() {
    Tratamiento fluor = con(180, 12);

    assertThat(fluor.fechaSugerida(HOY, 8)).contains(HOY.plusDays(180));
    assertThat(fluor.fechaSugerida(HOY, 12)).contains(HOY.plusDays(180));
    assertThat(fluor.fechaSugerida(HOY, 13)).isEmpty();
    assertThat(fluor.fechaSugerida(HOY, null)).isEmpty(); // sin edad registrada
  }
}
