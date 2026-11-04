package pe.gerenzdent.auth.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import pe.gerenzdent.shared.domain.EntidadAuditable;

/**
 * Refresh token de un solo uso (rotación). Solo se guarda su hash SHA-256: si alguien lee la BD no
 * puede usar los tokens.
 */
@Entity
@Table(name = "refresh_token")
public class RefreshToken extends EntidadAuditable {

  @Column(name = "usuario_id", nullable = false)
  private UUID usuarioId;

  @Column(name = "token_hash", nullable = false, length = 64)
  private String tokenHash;

  @Column(name = "expira_en", nullable = false)
  private Instant expiraEn;

  @Column(name = "revocado_en")
  private Instant revocadoEn;

  protected RefreshToken() {}

  public RefreshToken(UUID usuarioId, String tokenHash, Instant expiraEn) {
    this.usuarioId = usuarioId;
    this.tokenHash = tokenHash;
    this.expiraEn = expiraEn;
  }

  public boolean estaRevocado() {
    return revocadoEn != null;
  }

  public boolean estaVencido(Instant ahora) {
    return !ahora.isBefore(expiraEn);
  }

  public void revocar(Instant ahora) {
    if (revocadoEn == null) {
      revocadoEn = ahora;
    }
  }

  public UUID getUsuarioId() {
    return usuarioId;
  }
}
