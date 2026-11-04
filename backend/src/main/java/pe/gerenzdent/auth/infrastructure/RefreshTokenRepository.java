package pe.gerenzdent.auth.infrastructure;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import pe.gerenzdent.auth.domain.RefreshToken;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

  Optional<RefreshToken> findByTokenHash(String tokenHash);

  /** Cierra todas las sesiones del usuario (se usa al detectar reutilización de un token). */
  @Modifying
  @Query(
      "update RefreshToken t set t.revocadoEn = :ahora"
          + " where t.usuarioId = :usuarioId and t.revocadoEn is null")
  int revocarTodos(@Param("usuarioId") UUID usuarioId, @Param("ahora") Instant ahora);

  /** Limpieza: borra tokens vencidos o revocados antes de {@code limite}. */
  @Modifying
  @Query("delete from RefreshToken t where t.expiraEn < :limite or t.revocadoEn < :limite")
  int borrarAntiguos(@Param("limite") Instant limite);
}
