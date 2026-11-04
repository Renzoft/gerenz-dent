package pe.gerenzdent.control.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.control.domain.PlanTratamiento;

public interface PlanTratamientoRepository extends JpaRepository<PlanTratamiento, UUID> {

  Optional<PlanTratamiento> findByPacienteIdAndTratamientoIdAndEstado(
      UUID pacienteId, UUID tratamientoId, PlanTratamiento.Estado estado);
}
