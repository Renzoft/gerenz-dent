package pe.gerenzdent.auth.application;

import java.time.Duration;
import pe.gerenzdent.auth.domain.Usuario;

/** Resultado de un login o refresh: par de tokens + usuario. */
public record Sesion(
    String accessToken, String refreshToken, Duration duracionAccessToken, Usuario usuario) {}
