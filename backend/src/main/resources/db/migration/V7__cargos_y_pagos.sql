-- Iteración 4 (HU-21 a HU-25): deudas y pagos. Ver docs/planificacion/03-modelo-de-datos.md §2.1.
-- Deuda del paciente = Σ cargos válidos − Σ pagos válidos (nunca se guarda: se calcula).

CREATE TABLE cargo (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_tratamiento_id  uuid           NOT NULL REFERENCES plan_tratamiento (id),
    -- Solo los cargos MENSUAL apuntan al control en el que se cobró la cuota.
    control_id           uuid           REFERENCES control (id),
    concepto             varchar(15)    NOT NULL
        CHECK (concepto IN ('INICIAL', 'MENSUAL', 'TRATAMIENTO', 'OTRO')),
    descripcion          varchar(80),
    monto                numeric(10, 2) NOT NULL CHECK (monto >= 0),
    fecha                date           NOT NULL,
    estado               varchar(10)    NOT NULL DEFAULT 'VALIDO' CHECK (estado IN ('VALIDO', 'ANULADO')),
    motivo_anulacion     varchar(140),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now()
);

-- Una sola cuota válida por control.
CREATE UNIQUE INDEX uq_cargo_control_valido
    ON cargo (control_id)
    WHERE control_id IS NOT NULL AND estado = 'VALIDO';
CREATE INDEX ix_cargo_plan ON cargo (plan_tratamiento_id);

CREATE TABLE pago (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    plan_tratamiento_id  uuid           NOT NULL REFERENCES plan_tratamiento (id),
    monto                numeric(10, 2) NOT NULL CHECK (monto > 0),
    fecha                date           NOT NULL,
    medio                varchar(15)    NOT NULL
        CHECK (medio IN ('EFECTIVO', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'TARJETA', 'OTRO')),
    nota                 varchar(140),
    estado               varchar(10)    NOT NULL DEFAULT 'VALIDO' CHECK (estado IN ('VALIDO', 'ANULADO')),
    motivo_anulacion     varchar(140),
    created_at           timestamptz    NOT NULL DEFAULT now(),
    updated_at           timestamptz    NOT NULL DEFAULT now()
);

CREATE INDEX ix_pago_plan ON pago (plan_tratamiento_id);

-- Planes creados en las iteraciones 2 y 3 (antes de existir los cargos): se les genera el cargo
-- que habrían tenido, con el precio del catálogo. El doctor puede ajustarlo después.
INSERT INTO cargo (plan_tratamiento_id, concepto, monto, fecha)
SELECT p.id,
       CASE t.tipo_precio WHEN 'INICIAL_MAS_MENSUAL' THEN 'INICIAL' ELSE 'TRATAMIENTO' END,
       CASE t.tipo_precio WHEN 'POR_PIEZA' THEN t.precio_base * COALESCE(p.piezas, 1) ELSE t.precio_base END,
       p.fecha_inicio
FROM plan_tratamiento p
JOIN tratamiento t ON t.id = p.tratamiento_id
WHERE t.precio_base IS NOT NULL;

-- Cuotas mensuales de los controles de brackets a los que el paciente ya asistió.
INSERT INTO cargo (plan_tratamiento_id, control_id, concepto, monto, fecha)
SELECT c.plan_tratamiento_id, c.id, 'MENSUAL', t.precio_mensual, COALESCE(c.cerrado_en, c.fecha)
FROM control c
JOIN plan_tratamiento p ON p.id = c.plan_tratamiento_id
JOIN tratamiento t ON t.id = p.tratamiento_id
WHERE t.tipo_precio = 'INICIAL_MAS_MENSUAL'
  AND t.precio_mensual IS NOT NULL
  AND c.estado = 'ASISTIO';
