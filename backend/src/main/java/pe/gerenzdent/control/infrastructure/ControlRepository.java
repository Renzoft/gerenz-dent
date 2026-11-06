package pe.gerenzdent.control.infrastructure;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import pe.gerenzdent.control.domain.Control;
import pe.gerenzdent.control.domain.EstadoControl;

/**
 * Las consultas filtran siempre por el usuario dueño del paciente, para que nadie vea controles
 * ajenos. Devuelven {@code Object[] {Control, Paciente}} cuando la respuesta necesita al paciente.
 */
public interface ControlRepository extends JpaRepository<Control, UUID> {

  @Query(
      """
      select c from Control c join fetch c.plan p join fetch p.tratamiento
      where c.id = :id
        and p.pacienteId in (select pa.id from Paciente pa where pa.usuarioId = :usuarioId)
      """)
  Optional<Control> buscarDelUsuario(@Param("id") UUID id, @Param("usuarioId") UUID usuarioId);

  @Query(
      """
      select c from Control c join fetch c.plan p join fetch p.tratamiento
      where p.pacienteId = :pacienteId
      order by c.fecha desc, c.createdAt desc
      """)
  List<Control> historialDePaciente(@Param("pacienteId") UUID pacienteId);

  @Query("select c from Control c where c.plan.id = :planId and c.estado in :abiertos")
  Optional<Control> abiertoDelPlan(
      @Param("planId") UUID planId, @Param("abiertos") Collection<EstadoControl> abiertos);

  /** Controles abiertos entre dos fechas, de pacientes activos (agenda y "mañana"). */
  @Query(
      """
      select c, pa from Control c join fetch c.plan p join fetch p.tratamiento,
        Paciente pa
      where pa.id = p.pacienteId and pa.usuarioId = :usuarioId and pa.archivado = false
        and c.estado in :abiertos and c.fecha between :desde and :hasta
      order by c.fecha, c.hora nulls first, pa.nombreBusqueda
      """)
  List<Object[]> agenda(
      @Param("usuarioId") UUID usuarioId,
      @Param("desde") LocalDate desde,
      @Param("hasta") LocalDate hasta,
      @Param("abiertos") Collection<EstadoControl> abiertos);

  /** Controles abiertos con fecha pasada, de pacientes activos (RN-05). El más atrasado primero. */
  @Query(
      """
      select c, pa from Control c join fetch c.plan p join fetch p.tratamiento,
        Paciente pa
      where pa.id = p.pacienteId and pa.usuarioId = :usuarioId and pa.archivado = false
        and c.estado in :abiertos and c.fecha < :hoy
      order by c.fecha, pa.nombreBusqueda
      """)
  List<Object[]> vencidos(
      @Param("usuarioId") UUID usuarioId,
      @Param("hoy") LocalDate hoy,
      @Param("abiertos") Collection<EstadoControl> abiertos);

  /**
   * Controles marcados "no asistió" que siguen sin fecha nueva: es el último control de un plan
   * activo, sin otro control posterior ni abierto, de un paciente activo. Siguen en "No vinieron"
   * hasta que se les agende otro control.
   */
  @Query(
      """
      select c, pa from Control c join fetch c.plan p join fetch p.tratamiento,
        Paciente pa
      where pa.id = p.pacienteId and pa.usuarioId = :usuarioId and pa.archivado = false
        and c.estado = pe.gerenzdent.control.domain.EstadoControl.NO_ASISTIO
        and p.estado = pe.gerenzdent.control.domain.PlanTratamiento.Estado.ACTIVO
        and not exists (
          select 1 from Control otro
          where otro.plan = p and otro.id <> c.id
            and (otro.fecha >= c.fecha or otro.estado in :abiertos))
      order by c.fecha, pa.nombreBusqueda
      """)
  List<Object[]> noVinieronSinFecha(
      @Param("usuarioId") UUID usuarioId, @Param("abiertos") Collection<EstadoControl> abiertos);
}
