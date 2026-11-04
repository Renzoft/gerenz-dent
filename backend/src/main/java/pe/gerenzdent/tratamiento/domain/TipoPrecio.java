package pe.gerenzdent.tratamiento.domain;

/** Cómo cobra el consultorio un tratamiento (docs/planificacion/08-catalogo-tratamientos.md). */
public enum TipoPrecio {
  /** Un precio por tratamiento. */
  FIJO,
  /** Precio por diente (puentes, carillas). */
  POR_PIEZA,
  /** Pago inicial + cuota cada vez que el paciente asiste (brackets). */
  INICIAL_MAS_MENSUAL
}
