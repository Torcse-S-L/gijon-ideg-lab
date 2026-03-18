-- =============================================================================
-- 02-inspire-schema.sql
-- Esquemas INSPIRE para la IDEG del Ayuntamiento de Gijón/Xixón
-- Basado en la Directiva 2007/2/CE y LISIGE (Ley 14/2010)
-- SRS de referencia: EPSG:25830 (ETRS89 UTM Zone 30N)
-- =============================================================================

SET search_path = gis, public;

-- ─── Cartografía base ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.municipio (
    id           SERIAL PRIMARY KEY,
    codigo_ine   CHAR(5) NOT NULL UNIQUE,
    nombre       TEXT NOT NULL,
    nombre_ast   TEXT,                          -- Denominación en asturiano
    poblacion    INTEGER,
    superficie_ha NUMERIC(10,2),
    geom         GEOMETRY(MultiPolygon, 25830) NOT NULL,
    fecha_act    TIMESTAMPTZ DEFAULT now(),
    fuente       TEXT DEFAULT 'Catastro - IGN'
);
CREATE INDEX IF NOT EXISTS idx_municipio_geom ON gis.municipio USING GIST(geom);

CREATE TABLE IF NOT EXISTS gis.callejero (
    id           SERIAL PRIMARY KEY,
    via_id       TEXT NOT NULL,
    tipo_via     TEXT,
    nombre       TEXT NOT NULL,
    nombre_ast   TEXT,
    municipio_id INTEGER REFERENCES gis.municipio(id),
    geom         GEOMETRY(MultiLineString, 25830) NOT NULL,
    fecha_act    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_callejero_geom    ON gis.callejero USING GIST(geom);
CREATE INDEX IF NOT EXISTS idx_callejero_nombre  ON gis.callejero USING GIN(nombre gin_trgm_ops);

-- ─── Urbanismo ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.plan_general (
    id              SERIAL PRIMARY KEY,
    clasificacion   TEXT NOT NULL,  -- urbano, urbanizable, no_urbanizable
    calificacion    TEXT,
    descripcion     TEXT,
    geom            GEOMETRY(MultiPolygon, 25830) NOT NULL,
    vigente         BOOLEAN DEFAULT true,
    fecha_aprobacion DATE,
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_plan_general_geom ON gis.plan_general USING GIST(geom);

CREATE TABLE IF NOT EXISTS gis.licencia_urbanistica (
    id              SERIAL PRIMARY KEY,
    expediente      TEXT NOT NULL UNIQUE,
    tipo            TEXT,   -- hosteleria, terraza, vivienda_turistica, obras
    estado          TEXT,   -- solicitada, concedida, denegada, caducada
    titular         TEXT,
    direccion       TEXT,
    municipio_id    INTEGER REFERENCES gis.municipio(id),
    geom            GEOMETRY(Point, 25830),
    fecha_solicitud DATE,
    fecha_resolucion DATE,
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_licencia_geom ON gis.licencia_urbanistica USING GIST(geom);

-- ─── Patrimonio municipal ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.inventario_bienes (
    id              SERIAL PRIMARY KEY,
    codigo          TEXT NOT NULL UNIQUE,
    denominacion    TEXT NOT NULL,
    tipo            TEXT,  -- inmueble, mueble, derecho
    descripcion     TEXT,
    valor_catastral NUMERIC(14,2),
    municipio_id    INTEGER REFERENCES gis.municipio(id),
    geom            GEOMETRY(Geometry, 25830),
    fecha_alta      DATE,
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bienes_geom ON gis.inventario_bienes USING GIST(geom);

-- ─── Medio ambiente ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.zonas_verdes (
    id              SERIAL PRIMARY KEY,
    nombre          TEXT NOT NULL,
    tipo            TEXT,  -- parque, jardin, arbolado, zona_recreo
    superficie_m2   NUMERIC(10,2),
    municipio_id    INTEGER REFERENCES gis.municipio(id),
    geom            GEOMETRY(MultiPolygon, 25830) NOT NULL,
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_zonas_verdes_geom ON gis.zonas_verdes USING GIST(geom);

CREATE TABLE IF NOT EXISTS gis.arbolado (
    id              SERIAL PRIMARY KEY,
    especie         TEXT,
    nombre_comun    TEXT,
    altura_m        NUMERIC(5,1),
    diametro_copa_m NUMERIC(5,1),
    estado          TEXT,  -- bueno, regular, malo, eliminado
    zona_verde_id   INTEGER REFERENCES gis.zonas_verdes(id),
    geom            GEOMETRY(Point, 25830) NOT NULL,
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_arbolado_geom ON gis.arbolado USING GIST(geom);

-- ─── Movilidad ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.aparcamiento (
    id              SERIAL PRIMARY KEY,
    nombre          TEXT,
    tipo            TEXT,  -- superficie, subterraneo, carga_descarga
    plazas_total    INTEGER,
    plazas_pmr      INTEGER,  -- plazas personas movilidad reducida
    tarifa          TEXT,
    geom            GEOMETRY(MultiPolygon, 25830),
    fecha_act       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_aparcamiento_geom ON gis.aparcamiento USING GIST(geom);

-- ─── Ortofotos históricas ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS gis.ortofoto (
    id              SERIAL PRIMARY KEY,
    anio            INTEGER NOT NULL,
    resolucion_m    NUMERIC(4,2),
    sistema_ref     TEXT DEFAULT 'ETRS89 UTM 30N',
    url_wms         TEXT,
    url_wmts        TEXT,
    cobertura       GEOMETRY(MultiPolygon, 25830),
    fecha_vuelo     DATE,
    fuente          TEXT
);
CREATE INDEX IF NOT EXISTS idx_ortofoto_cobertura ON gis.ortofoto USING GIST(cobertura);

-- ─── Catálogo de recursos IDEG ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS catalog.recurso (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    titulo          TEXT NOT NULL,
    descripcion     TEXT,
    tipo            TEXT NOT NULL,  -- dataset, servicio_wms, servicio_wfs, etc.
    categoria       TEXT,           -- urbanismo, medio_ambiente, patrimonio, etc.
    nivel_acceso    TEXT NOT NULL CHECK (nivel_acceso IN
                        ('publico','publico_protegido','interno_publico','interno_privado')),
    url_servicio    TEXT,
    identificador_inspire TEXT,     -- identificador único para IDEE
    responsable_id  TEXT,           -- departamento productor
    fecha_creacion  DATE,
    fecha_revision  DATE,
    activo          BOOLEAN DEFAULT true,
    geom_bbox       GEOMETRY(Polygon, 4326)  -- bounding box en WGS84 para INSPIRE
);
CREATE INDEX IF NOT EXISTS idx_recurso_nivel ON catalog.recurso(nivel_acceso);
CREATE INDEX IF NOT EXISTS idx_recurso_tipo  ON catalog.recurso(tipo);
