-- Iteración 2 (HU-08, HU-09): catálogo de tratamientos del consultorio.
-- Fuente: docs/planificacion/08-catalogo-tratamientos.md (validado con el Dr. Marco Munayco).

CREATE TABLE tratamiento (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre                  varchar(80)   NOT NULL,
    tipo_precio             varchar(25)   NOT NULL
        CHECK (tipo_precio IN ('FIJO', 'POR_PIEZA', 'INICIAL_MAS_MENSUAL')),
    precio_base             numeric(10, 2) CHECK (precio_base >= 0),
    precio_mensual          numeric(10, 2) CHECK (precio_mensual >= 0),
    -- Días para sugerir la fecha del próximo control (null = sin sugerencia).
    intervalo_control_dias  integer       CHECK (intervalo_control_dias > 0),
    -- Si no es null, la sugerencia solo aplica a pacientes con edad <= este valor.
    edad_maxima_control     integer       CHECK (edad_maxima_control BETWEEN 0 AND 120),
    orden                   integer       NOT NULL DEFAULT 0,
    activo                  boolean       NOT NULL DEFAULT true,
    created_at              timestamptz   NOT NULL DEFAULT now(),
    updated_at              timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT uq_tratamiento_nombre UNIQUE (nombre),
    CONSTRAINT ck_tratamiento_mensual
        CHECK (tipo_precio <> 'INICIAL_MAS_MENSUAL' OR precio_mensual IS NOT NULL)
);

INSERT INTO tratamiento
    (nombre, tipo_precio, precio_base, precio_mensual, intervalo_control_dias, edad_maxima_control, orden)
VALUES
    ('Blanqueamiento dental',                    'FIJO',                 200.00, NULL,   NULL, NULL, 1),
    ('Brackets (ortodoncia)',                    'INICIAL_MAS_MENSUAL',  500.00, 100.00, 30,   NULL, 2),
    ('Prótesis dental completa (juego)',         'FIJO',                1000.00, NULL,   NULL, NULL, 3),
    ('Prótesis dental parcial acrílica',         'FIJO',                 400.00, NULL,   NULL, NULL, 4),
    ('Prótesis dental parcial metálica',         'FIJO',                 800.00, NULL,   NULL, NULL, 5),
    ('Puente fijo de Ivocron',                   'POR_PIEZA',            150.00, NULL,   NULL, NULL, 6),
    ('Puente de porcelana',                      'POR_PIEZA',            400.00, NULL,   NULL, NULL, 7),
    ('Puente de disilicato de litio',            'POR_PIEZA',            500.00, NULL,   NULL, NULL, 8),
    ('Puente de zirconio',                       'POR_PIEZA',            700.00, NULL,   NULL, NULL, 9),
    ('Limpieza dental y profilaxis',             'FIJO',                  80.00, NULL,   180,  12,   10),
    ('Extracción dental',                        'FIJO',                  70.00, NULL,   NULL, NULL, 11),
    ('Carillas dentales de disilicato de litio', 'POR_PIEZA',            600.00, NULL,   NULL, NULL, 12),
    ('Aplicación de flúor',                      'FIJO',                  50.00, NULL,   180,  12,   13),
    ('Carillas directas de resina',              'POR_PIEZA',            200.00, NULL,   NULL, NULL, 14);
