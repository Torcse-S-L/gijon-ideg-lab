-- =============================================================================
-- 001_inspire_metadata.sql
-- Tablas de metadatos conformes a la Directiva INSPIRE / ISO 19115
-- =============================================================================

SET search_path = inspire, public;

-- Tabla principal de metadatos INSPIRE (perfil mínimo obligatorio)
CREATE TABLE IF NOT EXISTS inspire.metadata (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_identifier     TEXT UNIQUE NOT NULL,       -- identificador único del registro
    language            CHAR(3) DEFAULT 'spa',
    character_set       TEXT DEFAULT 'utf8',
    hierarchy_level     TEXT DEFAULT 'dataset'
                            CHECK (hierarchy_level IN
                                ('dataset','series','service','tile','attribute')),
    -- Identificación
    title               TEXT NOT NULL,
    abstract            TEXT,
    topic_category      TEXT[],                     -- ej: {environment, boundaries}
    keywords            TEXT[],
    -- Extensión temporal
    date_creation       DATE,
    date_publication    DATE,
    date_revision       DATE,
    -- Extensión espacial
    bbox_west           NUMERIC(9,6),
    bbox_east           NUMERIC(9,6),
    bbox_south          NUMERIC(9,6),
    bbox_north          NUMERIC(9,6),
    ref_system          TEXT DEFAULT 'EPSG:25830',
    -- Calidad
    lineage             TEXT,
    spatial_resolution_m NUMERIC(8,2),
    conformance_inspire BOOLEAN DEFAULT false,
    -- Acceso
    access_constraints  TEXT DEFAULT 'license',
    use_limitations     TEXT,
    online_url          TEXT,
    -- Contacto del responsable
    org_name            TEXT,
    org_email           TEXT,
    -- Metadatos del metadato
    metadata_date       DATE DEFAULT CURRENT_DATE,
    metadata_language   CHAR(3) DEFAULT 'spa',
    catalog_id          UUID REFERENCES catalog.recurso(id)
);

CREATE INDEX IF NOT EXISTS idx_meta_hierarchy   ON inspire.metadata(hierarchy_level);
CREATE INDEX IF NOT EXISTS idx_meta_keywords    ON inspire.metadata USING GIN(keywords);
CREATE INDEX IF NOT EXISTS idx_meta_bbox        ON inspire.metadata(bbox_west, bbox_east, bbox_south, bbox_north);

-- Tabla de contactos de responsabilidad
CREATE TABLE IF NOT EXISTS inspire.responsible_party (
    id              SERIAL PRIMARY KEY,
    metadata_id     UUID REFERENCES inspire.metadata(id) ON DELETE CASCADE,
    role            TEXT NOT NULL CHECK (role IN
                        ('resourceProvider','custodian','owner','user',
                         'distributor','originator','pointOfContact',
                         'principalInvestigator','processor','publisher','author')),
    org_name        TEXT NOT NULL,
    individual_name TEXT,
    position        TEXT,
    email           TEXT,
    phone           TEXT,
    address         TEXT,
    city            TEXT DEFAULT 'Gijón',
    country         TEXT DEFAULT 'España'
);

-- Registro inicial: organismo responsable
INSERT INTO inspire.responsible_party
    (metadata_id, role, org_name, individual_name, email, phone, city)
SELECT id, 'pointOfContact',
       'Ayuntamiento de Gijón/Xixón — Servicio de Sistemas de Información',
       'Jefe/a de la Sección de Desarrollo',
       'sistemas.informacion@gijon.es',
       '985 18 11 05',
       'Gijón'
FROM inspire.metadata
LIMIT 0;  -- placeholder, se pobla con configure_geonetwork.sh
