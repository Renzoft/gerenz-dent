-- Iteración 2 (HU-11 a HU-14): plan de tratamiento del paciente y sus controles (citas).
-- Ver docs/planificacion/03-modelo-de-datos.md. Los cargos y pagos llegan en la iteración 4.

CREATE TABLE plan_tratamiento (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paciente_id     uuid         NOT NULL REFERENCES paciente (id),
    tratamiento_id  uuid         NOT NULL REFERENCES tratamiento (id),
    piezas          integer      CHECK (piezas BETWEEN 1 AND 32),
    estado          varchar(15)  NOT NULL DEFAULT 'ACTIVO'
        CHECK (estado IN ('ACTIVO', 'FINALIZADO')),
    fecha_inicio    date         NOT NULL,
    created_at      timestamptz  NOT NULL DEFAULT now(),
    updated_at      timestamptz  NOT NULL DEFAULT now()
);

-- Un paciente tiene a lo más un plan activo por tratamiento.
CREATE UNIQUE INDEX uq_plan_activo
    ON plan_tratamiento (paciente_id, tratamiento_id)
    WHERE estado = 'ACTIVO';

CREATE TABLE control (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_tratamiento_id  uuid         NOT NULL REFERENCES plan_tratamiento (id),
    fecha                date         NOT NULL,
    hora                 time,
    nota                 varchar(140),
    estado               varchar(15)  NOT NULL DEFAULT 'PENDIENTE'
        CHECK (estado IN ('PENDIENTE', 'RECORDADO', 'CONFIRMADO', 'ASISTIO', 'NO_ASISTIO', 'CANCELADO')),
    created_at           timestamptz  NOT NULL DEFAULT now(),
    updated_at           timestamptz  NOT NULL DEFAULT now()
);

-- Un solo control abierto (pendiente/recordado/confirmado) por plan.
CREATE UNIQUE INDEX uq_control_abierto
    ON control (plan_tratamiento_id)
    WHERE estado IN ('PENDIENTE', 'RECORDADO', 'CONFIRMADO');

-- Listas de "mañana", agenda y "vencidos".
CREATE INDEX ix_control_fecha_estado ON control (fecha, estado);
CREATE INDEX ix_plan_paciente ON plan_tratamiento (paciente_id);
