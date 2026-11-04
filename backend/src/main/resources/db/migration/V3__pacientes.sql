-- Iteración 1 (HU-02 a HU-06): pacientes.

CREATE TABLE paciente (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id          uuid         NOT NULL REFERENCES usuario (id),
    nombre              varchar(80)  NOT NULL,
    -- nombre en minúsculas y sin tildes, para buscar "perez" y encontrar "Pérez"
    nombre_busqueda     varchar(80)  NOT NULL,
    whatsapp            varchar(16)  NOT NULL,  -- formato E.164: +51987654321
    edad                integer      CHECK (edad BETWEEN 0 AND 120),
    alergias            varchar(200),
    nota                varchar(300),
    consiente_whatsapp  boolean      NOT NULL DEFAULT true,
    archivado           boolean      NOT NULL DEFAULT false,
    created_at          timestamptz  NOT NULL DEFAULT now(),
    updated_at          timestamptz  NOT NULL DEFAULT now()
);

-- Un mismo número no puede estar en dos pacientes activos.
CREATE UNIQUE INDEX uq_paciente_whatsapp_activo
    ON paciente (usuario_id, whatsapp)
    WHERE archivado = false;

CREATE INDEX ix_paciente_usuario_archivado ON paciente (usuario_id, archivado);

-- Búsqueda parcial por nombre (LIKE '%texto%').
CREATE INDEX ix_paciente_nombre_busqueda_trgm
    ON paciente USING gin (nombre_busqueda gin_trgm_ops);
