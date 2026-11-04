package pe.gerenzdent.tratamiento.infrastructure;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

public interface TratamientoRepository extends JpaRepository<Tratamiento, UUID> {

  List<Tratamiento> findByActivoTrueOrderByOrdenAscNombreAsc();
}
