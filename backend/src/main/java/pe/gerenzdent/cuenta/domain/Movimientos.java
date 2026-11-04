package pe.gerenzdent.cuenta.domain;

import java.math.BigDecimal;
import java.util.Collection;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Textos;

/** Cálculos sobre cargos y pagos. */
public final class Movimientos {

  private Movimientos() {}

  public static BigDecimal totalCargos(Collection<Cargo> cargos) {
    return cargos.stream()
        .filter(Cargo::esValido)
        .map(Cargo::getMonto)
        .reduce(Montos.cero(), BigDecimal::add);
  }

  public static BigDecimal totalPagos(Collection<Pago> pagos) {
    return pagos.stream()
        .filter(Pago::esValido)
        .map(Pago::getMonto)
        .reduce(Montos.cero(), BigDecimal::add);
  }

  /** Saldo = cargos válidos − pagos válidos. Positivo = el paciente debe. */
  public static BigDecimal saldo(Collection<Cargo> cargos, Collection<Pago> pagos) {
    return totalCargos(cargos).subtract(totalPagos(pagos));
  }

  static String motivo(String motivo) {
    String limpio = Textos.limpiarOpcional(motivo);
    if (limpio == null) {
      throw new DatoInvalido("motivo", "Indica el motivo de la anulación.");
    }
    if (limpio.length() > 140) {
      throw new DatoInvalido("motivo", "Máximo 140 caracteres.");
    }
    return limpio;
  }
}
