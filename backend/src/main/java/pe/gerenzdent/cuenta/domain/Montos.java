package pe.gerenzdent.cuenta.domain;

import java.math.BigDecimal;
import java.math.RoundingMode;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;

/** Montos en soles: siempre {@link BigDecimal} con 2 decimales (nunca double). */
public final class Montos {

  public static final BigDecimal MAXIMO = new BigDecimal("99999.99");

  private Montos() {}

  /** Valida y redondea a céntimos. {@code permitirCero}: un cargo puede ser S/ 0 (cortesía). */
  public static BigDecimal validar(BigDecimal monto, String campo, boolean permitirCero) {
    if (monto == null) {
      throw new DatoInvalido(campo, "Ingresa el monto.");
    }
    BigDecimal valor = monto.setScale(2, RoundingMode.HALF_UP);
    if (valor.signum() < 0 || (!permitirCero && valor.signum() == 0)) {
      throw new DatoInvalido(
          campo, permitirCero ? "El monto no puede ser negativo." : "El monto debe ser mayor a 0.");
    }
    if (valor.compareTo(MAXIMO) > 0) {
      throw new DatoInvalido(campo, "El monto máximo es S/ 99,999.99.");
    }
    return valor;
  }

  public static BigDecimal cero() {
    return BigDecimal.ZERO.setScale(2);
  }
}
