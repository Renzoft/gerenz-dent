package pe.gerenzdent.auth.infrastructure;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.auth.domain.Usuario;

public interface UsuarioRepository extends JpaRepository<Usuario, UUID> {

  /** El email se guarda normalizado (minúsculas, sin espacios). */
  Optional<Usuario> findByEmail(String email);
}
