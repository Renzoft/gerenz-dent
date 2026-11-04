package pe.gerenzdent.tratamiento.infrastructure;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import pe.gerenzdent.tratamiento.domain.Tratamiento;

public interface TratamientoRepository extends JpaRepository<Tratamiento, UUID> {

  List<Tratamiento> findByActivoTrueOrderByOrdenAscNombreAsc();

  List<Tratamiento> findAllByOrderByActivoDescOrdenAscNombreAsc();

  boolean existsByNombreIgnoreCase(String nombre);

  boolean existsByNombreIgnoreCaseAndIdNot(String nombre, UUID id);

  @org.springframework.data.jpa.repository.Query(
      "select coalesce(max(t.orden), 0) from Tratamiento t")
  int ordenMaximo();
}
