package pe.gerenzdent.shared.api;

import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;
import pe.gerenzdent.shared.domain.Excepciones.Conflicto;
import pe.gerenzdent.shared.domain.Excepciones.CredencialesInvalidas;
import pe.gerenzdent.shared.domain.Excepciones.DatoInvalido;
import pe.gerenzdent.shared.domain.Excepciones.LoginBloqueado;
import pe.gerenzdent.shared.domain.Excepciones.RecursoNoEncontrado;
import pe.gerenzdent.shared.domain.Excepciones.SesionInvalida;

/** Traduce los errores a respuestas RFC 9457 (Problem Details) con mensajes en español. */
@RestControllerAdvice
public class ManejadorErrores extends ResponseEntityExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(ManejadorErrores.class);

  @ExceptionHandler(RecursoNoEncontrado.class)
  ProblemDetail noEncontrado(RecursoNoEncontrado ex) {
    return problema(HttpStatus.NOT_FOUND, "No encontrado", ex.getMessage());
  }

  @ExceptionHandler(DatoInvalido.class)
  ProblemDetail datoInvalido(DatoInvalido ex) {
    ProblemDetail p = problema(HttpStatus.BAD_REQUEST, "Datos inválidos", ex.getMessage());
    p.setProperty("errores", Map.of(ex.campo(), ex.getMessage()));
    return p;
  }

  @ExceptionHandler(Conflicto.class)
  ProblemDetail conflicto(Conflicto ex) {
    ProblemDetail p = problema(HttpStatus.CONFLICT, "Conflicto", ex.getMessage());
    ex.datos().forEach(p::setProperty);
    return p;
  }

  @ExceptionHandler({CredencialesInvalidas.class, SesionInvalida.class})
  ProblemDetail noAutenticado(RuntimeException ex) {
    return problema(HttpStatus.UNAUTHORIZED, "No autenticado", ex.getMessage());
  }

  @ExceptionHandler(LoginBloqueado.class)
  ResponseEntity<ProblemDetail> bloqueado(LoginBloqueado ex) {
    return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
        .header(HttpHeaders.RETRY_AFTER, String.valueOf(ex.minutosRestantes() * 60))
        .body(problema(HttpStatus.TOO_MANY_REQUESTS, "Demasiados intentos", ex.getMessage()));
  }

  /** Última defensa: una restricción única de la BD que la validación previa no atrapó. */
  @ExceptionHandler(DataIntegrityViolationException.class)
  ProblemDetail integridad(DataIntegrityViolationException ex) {
    log.warn(
        "Violación de integridad de datos: {}", ex.getMostSpecificCause().getClass().getName());
    return problema(
        HttpStatus.CONFLICT, "Conflicto", "El registro entra en conflicto con otro existente.");
  }

  /** Errores de Bean Validation: devuelve {"errores": {"campo": "mensaje"}}. */
  @Override
  protected ResponseEntity<Object> handleMethodArgumentNotValid(
      MethodArgumentNotValidException ex,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    Map<String, String> errores = new LinkedHashMap<>();
    for (FieldError error : ex.getBindingResult().getFieldErrors()) {
      errores.putIfAbsent(error.getField(), error.getDefaultMessage());
    }
    ProblemDetail p =
        problema(HttpStatus.BAD_REQUEST, "Datos inválidos", "Revisa los campos marcados.");
    p.setProperty("errores", errores);
    return ResponseEntity.badRequest().body(p);
  }

  private static ProblemDetail problema(HttpStatus estado, String titulo, String detalle) {
    ProblemDetail p = ProblemDetail.forStatusAndDetail(estado, detalle);
    p.setTitle(titulo);
    return p;
  }
}
