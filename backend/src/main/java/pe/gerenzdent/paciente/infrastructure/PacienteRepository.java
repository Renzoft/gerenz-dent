package pe.gerenzdent.paciente.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import pe.gerenzdent.paciente.domain.Paciente;

public interface PacienteRepository extends JpaRepository<Paciente, UUID> {

  Optional<Paciente> findByIdAndUsuarioId(UUID id, UUID usuarioId);

  Optional<Paciente> findFirstByUsuarioIdAndWhatsappAndArchivadoFalse(
      UUID usuarioId, String whatsapp);

  Page<Paciente> findByUsuarioIdAndArchivado(UUID usuarioId, boolean archivado, Pageable pagina);

  /** Búsqueda por parte del nombre (sin tildes ni mayúsculas). */
  @Query(
      """
      select p from Paciente p
      where p.usuarioId = :usuarioId and p.archivado = :archivado
        and p.nombreBusqueda like concat('%', :texto, '%')
      """)
  Page<Paciente> buscarPorNombre(
      @Param("usuarioId") UUID usuarioId,
      @Param("archivado") boolean archivado,
      @Param("texto") String texto,
      Pageable pagina);

  /** Búsqueda por parte del nombre o del número. */
  @Query(
      """
      select p from Paciente p
      where p.usuarioId = :usuarioId and p.archivado = :archivado
        and (p.nombreBusqueda like concat('%', :texto, '%')
             or p.whatsapp like concat('%', :digitos, '%'))
      """)
  Page<Paciente> buscarPorNombreONumero(
      @Param("usuarioId") UUID usuarioId,
      @Param("archivado") boolean archivado,
      @Param("texto") String texto,
      @Param("digitos") String digitos,
      Pageable pagina);
}
