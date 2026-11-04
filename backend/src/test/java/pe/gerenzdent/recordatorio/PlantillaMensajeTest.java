package pe.gerenzdent.recordatorio;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.time.LocalTime;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import pe.gerenzdent.recordatorio.domain.FormatoMensaje;
import pe.gerenzdent.recordatorio.domain.PlantillaMensaje;

class PlantillaMensajeTest {

  /** Martes 10 de noviembre de 2026. */
  private static final LocalDate HOY = LocalDate.of(2026, 11, 10);

  private static PlantillaMensaje.Datos datos(LocalDate fecha, LocalTime hora) {
    return new PlantillaMensaje.Datos(
        "Juan Pérez García", "Dr. Marco Munayco", "Brackets (ortodoncia)", fecha, hora);
  }

  @Test
  void recordatorioDeMananaConHora() {
    String m = PlantillaMensaje.recordatorio(datos(HOY.plusDays(1), LocalTime.of(19, 30)), HOY);

    assertThat(m)
        .isEqualTo(
            """
            Hola Juan 👋, le saluda el Dr. Marco Munayco del consultorio odontológico *GERENZ DENT*.
            Le recordamos su cita de *Brackets (ortodoncia)* para mañana *miércoles 11 de noviembre* a las 7:30 p. m.
            Por favor responda *SÍ* para confirmar, o escríbame si necesita cambiar la fecha. ¡Le espero! 🦷\
            """);
  }

  @ParameterizedTest(name = "{0} sin hora → {1}")
  @CsvSource(
      delimiter = '|',
      value = {
        "2026-11-11 | a partir de las 6:00 p. m.", // miércoles
        "2026-11-14 | a partir de las 4:00 p. m.", // sábado
        "2026-11-15 | a partir de las 8:00 a. m." // domingo
      })
  void sinHoraUsaLaAperturaDelDia(LocalDate fecha, String esperado) {
    assertThat(PlantillaMensaje.recordatorio(datos(fecha, null), HOY)).contains(esperado);
  }

  @Test
  void diceHoyOElDiaSegunLaFecha() {
    assertThat(PlantillaMensaje.recordatorio(datos(HOY, null), HOY))
        .contains("para hoy *martes 10 de noviembre*");
    assertThat(PlantillaMensaje.recordatorio(datos(HOY.plusDays(5), null), HOY))
        .contains("para el *domingo 15 de noviembre*");
  }

  @Test
  void seguimientoIndicaElHorarioDeAtencion() {
    String m = PlantillaMensaje.seguimiento(datos(HOY.minusDays(3), null));

    assertThat(m)
        .startsWith("Hola Juan 👋, le saluda el Dr. Marco Munayco de *GERENZ DENT*.")
        .contains("Aún tiene pendiente su control de *Brackets (ortodoncia)*")
        .contains(
            "de lunes a viernes desde las 6:00 p. m., los sábados desde las 4:00 p. m. y"
                + " los domingos de 8:00 a. m. a 10:00 p. m.");
  }

  @ParameterizedTest
  @CsvSource(
      delimiter = '|',
      value = {
        "Dr. Marco Munayco | el Dr. Marco Munayco",
        "Dra. Ana Ríos     | la Dra. Ana Ríos",
        "Marco Munayco     | Marco Munayco"
      })
  void articuloSegunElTitulo(String nombre, String esperado) {
    assertThat(FormatoMensaje.conArticulo(nombre)).isEqualTo(esperado);
  }

  @ParameterizedTest
  @CsvSource({"0, 0, 12:00 a. m.", "8, 5, 8:05 a. m.", "12, 0, 12:00 p. m.", "22, 0, 10:00 p. m."})
  void horaEnFormatoPeruano(int h, int m, String esperado) {
    assertThat(FormatoMensaje.hora(LocalTime.of(h, m))).isEqualTo(esperado);
  }
}
