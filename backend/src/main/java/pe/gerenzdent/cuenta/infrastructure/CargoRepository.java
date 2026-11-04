package pe.gerenzdent.cuenta.infrastructure;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import pe.gerenzdent.cuenta.domain.Cargo;

public interface CargoRepository extends JpaRepository<Cargo, UUID> {

  List<Cargo> findByPlanIdInOrderByFechaAscCreatedAtAsc(Collection<UUID> planIds);

  boolean existsByControlIdAndEstado(
      UUID controlId, pe.gerenzdent.cuenta.domain.EstadoMovimiento e);

  /** Σ cargos válidos por paciente del usuario: {pacienteId, total}. */
  @Query(
      """
      select p.pacienteId, sum(c.monto)
      from Cargo c, pe.gerenzdent.control.domain.PlanTratamiento p
      where p.id = c.planId and c.estado = pe.gerenzdent.cuenta.domain.EstadoMovimiento.VALIDO
        and p.pacienteId in (select pa.id from Paciente pa where pa.usuarioId = :usuarioId)
      group by p.pacienteId
      """)
  List<Object[]> totalesPorPaciente(@Param("usuarioId") UUID usuarioId);
}
