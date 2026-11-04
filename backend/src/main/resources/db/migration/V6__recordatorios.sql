-- Iteración 3 (HU-15 a HU-19): recordatorios por WhatsApp y fecha real de cierre del control.

-- Día real (hora de Lima) en que el control pasó a asistió / no asistió / cancelado.
-- Antes el historial mostraba la fecha planificada aunque el paciente viniera otro día.
ALTER TABLE control ADD COLUMN cerrado_en date;

UPDATE control
SET cerrado_en = (updated_at AT TIME ZONE 'America/Lima')::date
WHERE estado IN ('ASISTIO', 'NO_ASISTIO', 'CANCELADO');

-- Cada mensaje que el doctor confirma haber enviado.
CREATE TABLE recordatorio (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    control_id  uuid         NOT NULL REFERENCES control (id),
    tipo        varchar(15)  NOT NULL CHECK (tipo IN ('PREVIO', 'SEGUIMIENTO')),
    -- WHATSAPP_MANUAL: wa.me + el doctor presiona enviar (ADR-001).
    -- WHATSAPP_API queda reservado para el envío automático futuro.
    canal       varchar(20)  NOT NULL DEFAULT 'WHATSAPP_MANUAL'
        CHECK (canal IN ('WHATSAPP_MANUAL', 'WHATSAPP_API')),
    enviado_en  timestamptz  NOT NULL,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX ix_recordatorio_control ON recordatorio (control_id, enviado_en DESC);
