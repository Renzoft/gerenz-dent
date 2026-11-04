package pe.gerenzdent.paciente.domain;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

class NumeroWhatsappTest {

  @ParameterizedTest(name = "\"{0}\" → {1}")
  @CsvSource(
      delimiter = '|',
      value = {
        "987654321          | +51987654321",
        "987 654 321        | +51987654321",
        "987-654-321        | +51987654321",
        "(987) 654.321      | +51987654321",
        " 987654321         | +51987654321",
        "51987654321        | +51987654321",
        "+51987654321       | +51987654321",
        "+51 987 654 321    | +51987654321",
        "0051987654321      | +51987654321",
        "+1 415 555 2671    | +14155552671",
        "+34 612 345 678    | +34612345678",
        "0034612345678      | +34612345678"
      })
  void normalizaAFormatoE164(String entrada, String esperado) {
    assertThat(NumeroWhatsapp.normalizar(entrada)).isEqualTo(esperado);
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "12345678", // 8 dígitos sin código
        "887654321", // no empieza con 9
        "9876543210", // 10 dígitos
        "98765432", // 8 dígitos
        "51887654321", // Perú pero no celular
        "+51 1234567", // fijo de Lima con código
        "+0123456789", // código de país no puede empezar con 0
        "+1234567", // muy corto
        "+1234567890123456", // muy largo
        "987abc321",
        "+"
      })
  void rechazaNumerosInvalidos(String entrada) {
    assertThatThrownBy(() -> NumeroWhatsapp.normalizar(entrada))
        .isInstanceOf(DatoInvalido.class)
        .extracting("campo")
        .isEqualTo("whatsapp");
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(strings = {"   "})
  void exigeElNumero(String entrada) {
    assertThatThrownBy(() -> NumeroWhatsapp.normalizar(entrada))
        .isInstanceOf(DatoInvalido.class)
        .hasMessage("Ingresa el número de WhatsApp.");
  }
}
