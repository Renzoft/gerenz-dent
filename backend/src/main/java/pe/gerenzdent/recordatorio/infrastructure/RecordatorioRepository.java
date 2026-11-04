package pe.gerenzdent.recordatorio.infrastructure;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.recordatorio.domain.Recordatorio;

public interface RecordatorioRepository extends JpaRepository<Recordatorio, UUID> {

  List<Recordatorio> findByControlIdInOrderByEnviadoEnDesc(Collection<UUID> controlIds);
}
