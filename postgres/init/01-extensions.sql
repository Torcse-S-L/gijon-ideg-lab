-- =============================================================================
-- 01-extensions.sql
-- Activación de extensiones PostgreSQL necesarias para la IDEG de Gijón
-- =============================================================================

-- Extensiones espaciales y de texto
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Esquemas principales del IDEG
CREATE SCHEMA IF NOT EXISTS gis;        -- Datos georreferenciados municipales
CREATE SCHEMA IF NOT EXISTS inspire;    -- Metadatos y estructuras INSPIRE
CREATE SCHEMA IF NOT EXISTS compat;     -- Vistas de compatibilidad (apps legadas)
CREATE SCHEMA IF NOT EXISTS audit;      -- Auditoría de accesos y cambios
CREATE SCHEMA IF NOT EXISTS catalog;    -- Catálogo de recursos y capas

COMMENT ON SCHEMA gis     IS 'Datos georreferenciados del Ayuntamiento de Gijón/Xixón';
COMMENT ON SCHEMA inspire IS 'Metadatos conformes a la directiva INSPIRE / LISIGE';
COMMENT ON SCHEMA compat  IS 'Vistas de compatibilidad para herramientas GIS legadas';
COMMENT ON SCHEMA audit   IS 'Auditoría de accesos a servicios OGC y cambios de datos';
COMMENT ON SCHEMA catalog IS 'Catálogo de capas y recursos publicados por la IDEG';
