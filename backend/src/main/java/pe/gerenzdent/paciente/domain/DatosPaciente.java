package pe.gerenzdent.paciente.domain;

/** Datos editables de un paciente, tal como los ingresa el doctor (antes de normalizar). */
public record DatosPaciente(
    String nombre,
    String whatsapp,
    Integer edad,
    String alergias,
    String nota,
    boolean consienteWhatsapp) {}
