package pe.gerenzdent.control.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.control.domain.PlanTratamiento;

public interface PlanTratamientoRepository extends JpaRepository<PlanTratamiento, UUID> {

  Optional<PlanTratamiento> findByPacienteIdAndTratamientoIdAndEstado(
      UUID pacienteId, UUID tratamientoId, PlanTratamiento.Estado estado);

  /** Plan con su tratamiento ya cargado. */
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "tratamiento")
  Optional<PlanTratamiento> findConTratamientoById(UUID id);

  /** Planes del paciente con su tratamiento (cuenta de la ficha). */
  @org.springframework.data.jpa.repository.EntityGraph(attributePaths = "tratamiento")
  java.util.List<PlanTratamiento> findByPacienteIdOrderByFechaInicioDesc(UUID pacienteId);
}
