package pe.gerenzdent.cuenta.infrastructure;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import pe.gerenzdent.cuenta.domain.Pago;

public interface PagoRepository extends JpaRepository<Pago, UUID> {

  List<Pago> findByPlanIdInOrderByFechaAscCreatedAtAsc(Collection<UUID> planIds);

  /** Σ pagos válidos por paciente del usuario: {pacienteId, total}. */
  @Query(
      """
      select p.pacienteId, sum(g.monto)
      from Pago g, pe.gerenzdent.control.domain.PlanTratamiento p
      where p.id = g.planId and g.estado = pe.gerenzdent.cuenta.domain.EstadoMovimiento.VALIDO
        and p.pacienteId in (select pa.id from Paciente pa where pa.usuarioId = :usuarioId)
      group by p.pacienteId
      """)
  List<Object[]> totalesPorPaciente(@Param("usuarioId") UUID usuarioId);
}
