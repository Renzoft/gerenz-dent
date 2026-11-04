package pe.gerenzdent.paciente.api;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;
import pe.gerenzdent.paciente.domain.DatosPaciente;
import pe.gerenzdent.paciente.domain.Paciente;

/** Contratos JSON del módulo de pacientes. */
public final class PacienteDtos {

  private PacienteDtos() {}

  /**
   * Crear y editar usan el mismo cuerpo. {@code consienteWhatsapp} es opcional y vale {@code true}
   * por defecto (el doctor lo pregunta de palabra al registrar).
   */
  public record PacienteRequest(
      @NotBlank(message = "Ingresa el nombre")
          @Size(
              min = Paciente.NOMBRE_MIN,
              max = Paciente.NOMBRE_MAX,
              message = "El nombre debe tener entre 2 y 80 caracteres")
          String nombre,
      @NotBlank(message = "Ingresa el número de WhatsApp") @Size(max = 25) String whatsapp,
      @Min(value = 0, message = "La edad no puede ser negativa")
          @Max(value = Paciente.EDAD_MAX, message = "La edad máxima es 120")
          Integer edad,
      @Size(max = Paciente.ALERGIAS_MAX, message = "Máximo 200 caracteres") String alergias,
      @Size(max = Paciente.NOTA_MAX, message = "Máximo 300 caracteres") String nota,
      Boolean consienteWhatsapp) {

    DatosPaciente aDatos() {
      return new DatosPaciente(
          nombre, whatsapp, edad, alergias, nota, consienteWhatsapp == null || consienteWhatsapp);
    }
  }

  public record PacienteResponse(
      UUID id,
      String nombre,
      String whatsapp,
      Integer edad,
      String alergias,
      String nota,
      boolean consienteWhatsapp,
      boolean archivado,
      Instant creadoEn,
      Instant actualizadoEn) {

    static PacienteResponse de(Paciente p) {
      return new PacienteResponse(
          p.getId(),
          p.getNombre(),
          p.getWhatsapp(),
          p.getEdad(),
          p.getAlergias(),
          p.getNota(),
          p.isConsienteWhatsapp(),
          p.isArchivado(),
          p.getCreatedAt(),
          p.getUpdatedAt());
    }
  }
}
