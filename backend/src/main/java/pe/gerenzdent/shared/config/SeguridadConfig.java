package pe.gerenzdent.shared.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import jakarta.servlet.http.HttpServletResponse;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.factory.PasswordEncoderFactories;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.access.AccessDeniedHandler;

/**
 * API sin estado: cada petición lleva un JWT (access token) firmado con HS256. No hay cookies, por
 * eso CSRF está desactivado. Tampoco hay CORS: el cliente es la app móvil, no un navegador.
 */
@Configuration
public class SeguridadConfig {

  private static final String[] RUTAS_PUBLICAS = {
    "/actuator/health",
    "/actuator/health/**",
    "/actuator/info",
    "/api/v1/auth/login",
    "/api/v1/auth/refresh",
    // El refresh token es la credencial: se debe poder cerrar sesión aunque el access token venció.
    "/api/v1/auth/logout",
    "/v3/api-docs/**",
    "/swagger-ui/**",
    "/swagger-ui.html",
    "/error"
  };

  @Bean
  SecurityFilterChain cadenaDeSeguridad(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .cors(cors -> cors.disable())
        .httpBasic(basic -> basic.disable())
        .formLogin(form -> form.disable())
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(
            auth -> auth.requestMatchers(RUTAS_PUBLICAS).permitAll().anyRequest().authenticated())
        .oauth2ResourceServer(oauth ->
            oauth
                .jwt(Customizer.withDefaults())
                .authenticationEntryPoint(noAutenticado())
                .accessDeniedHandler(accesoDenegado()))
        .exceptionHandling(ex ->
            ex.authenticationEntryPoint(noAutenticado()).accessDeniedHandler(accesoDenegado()));
    return http.build();
  }

  @Bean
  SecretKey claveJwt(PropiedadesSeguridad propiedades) {
    return new SecretKeySpec(
        propiedades.jwtSecreto().getBytes(StandardCharsets.UTF_8), "HmacSHA256");
  }

  @Bean
  JwtEncoder jwtEncoder(SecretKey claveJwt) {
    return new NimbusJwtEncoder(new ImmutableSecret<>(claveJwt));
  }

  @Bean
  JwtDecoder jwtDecoder(SecretKey claveJwt) {
    return NimbusJwtDecoder.withSecretKey(claveJwt).macAlgorithm(MacAlgorithm.HS256).build();
  }

  @Bean
  PasswordEncoder passwordEncoder() {
    return PasswordEncoderFactories.createDelegatingPasswordEncoder();
  }

  @Bean
  Clock reloj() {
    return Clock.systemUTC();
  }

  private static AuthenticationEntryPoint noAutenticado() {
    return (request, response, ex) ->
        escribirProblema(
            response,
            HttpServletResponse.SC_UNAUTHORIZED,
            "No autenticado",
            "Inicia sesión para continuar.");
  }

  private static AccessDeniedHandler accesoDenegado() {
    return (request, response, ex) ->
        escribirProblema(
            response,
            HttpServletResponse.SC_FORBIDDEN,
            "Acceso denegado",
            "No tienes permiso para esta acción.");
  }

  /** Respuesta en formato RFC 9457 (Problem Details), igual que el resto de errores de la API. */
  private static void escribirProblema(
      HttpServletResponse response, int estado, String titulo, String detalle)
      throws java.io.IOException {
    response.setStatus(estado);
    response.setContentType("application/problem+json");
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    response
        .getWriter()
        .write(
            "{\"type\":\"about:blank\",\"title\":\"%s\",\"status\":%d,\"detail\":\"%s\"}"
                .formatted(titulo, estado, detalle));
  }
}
