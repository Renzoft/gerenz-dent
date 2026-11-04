-- Iteración 0: extensiones base.
-- pg_trgm: búsqueda parcial de pacientes por nombre (índice GIN, ver docs/planificacion/03-modelo-de-datos.md).
-- gen_random_uuid() ya es nativo desde PostgreSQL 13, no requiere extensión.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
