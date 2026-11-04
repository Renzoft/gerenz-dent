-- Iteración 1 (HU-01): usuario del consultorio y refresh tokens.

CREATE TABLE usuario (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email              varchar(120) NOT NULL,
    password_hash      varchar(100) NOT NULL,
    nombre             varchar(80)  NOT NULL,
    hora_notificacion  time         NOT NULL DEFAULT '17:30',
    intentos_fallidos  integer      NOT NULL DEFAULT 0,
    bloqueado_hasta    timestamptz,
    created_at         timestamptz  NOT NULL DEFAULT now(),
    updated_at         timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT uq_usuario_email UNIQUE (email)
);

-- Solo se guarda el hash SHA-256 del refresh token, nunca el token.
CREATE TABLE refresh_token (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id   uuid         NOT NULL REFERENCES usuario (id) ON DELETE CASCADE,
    token_hash   varchar(64)  NOT NULL,
    expira_en    timestamptz  NOT NULL,
    revocado_en  timestamptz,
    created_at   timestamptz  NOT NULL DEFAULT now(),
    updated_at   timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);

CREATE INDEX ix_refresh_token_usuario ON refresh_token (usuario_id);
