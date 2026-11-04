package pe.gerenzdent.shared.api;

import java.util.List;
import java.util.function.Function;
import org.springframework.data.domain.Page;

/** Formato estable de las respuestas paginadas (no expone la estructura interna de Spring). */
public record PaginaResponse<T>(
    List<T> contenido, int pagina, int tamano, long totalElementos, int totalPaginas) {

  public static <E, T> PaginaResponse<T> de(Page<E> pagina, Function<E, T> mapeo) {
    return new PaginaResponse<>(
        pagina.getContent().stream().map(mapeo).toList(),
        pagina.getNumber(),
        pagina.getSize(),
        pagina.getTotalElements(),
        pagina.getTotalPages());
  }
}
