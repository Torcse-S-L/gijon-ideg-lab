-- =============================================================================
-- 03-sample-data-gijon.sql
-- Datos de ejemplo del municipio de Gijón/Xixón (EPSG:25830)
-- Geometrías simplificadas para laboratorio — no para uso cartográfico oficial
-- =============================================================================

SET search_path = gis, public;

-- ─── Municipio de Gijón ──────────────────────────────────────────────────────
INSERT INTO gis.municipio (codigo_ine, nombre, nombre_ast, poblacion, superficie_ha, geom)
VALUES (
    '33024',
    'Gijón',
    'Xixón',
    271843,
    18188,
    ST_SetSRID(ST_GeomFromText(
        'MULTIPOLYGON(((272000 4824000, 290000 4824000, 290000 4836000, 272000 4836000, 272000 4824000)))'
    ), 25830)
) ON CONFLICT (codigo_ine) DO NOTHING;

-- ─── Barrios / Distritos ─────────────────────────────────────────────────────
INSERT INTO gis.zonas_verdes (nombre, tipo, superficie_m2, municipio_id, geom) VALUES
    ('Parque de Isabel la Católica', 'parque',     375000, 1,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((279500 4828500, 280200 4828500, 280200 4829200, 279500 4829200, 279500 4828500)))'), 25830)),
    ('Jardín de la Reina',           'jardin',      12000, 1,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((280100 4829500, 280300 4829500, 280300 4829700, 280100 4829700, 280100 4829500)))'), 25830)),
    ('Parque del Lauredal',          'parque',      58000, 1,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((278000 4831000, 278600 4831000, 278600 4831600, 278000 4831600, 278000 4831000)))'), 25830)),
    ('Playa de San Lorenzo',         'zona_recreo', 45000, 1,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((281000 4830500, 282500 4830500, 282500 4830800, 281000 4830800, 281000 4830500)))'), 25830))
ON CONFLICT DO NOTHING;

-- ─── Inventario bienes patrimoniales ─────────────────────────────────────────
INSERT INTO gis.inventario_bienes (codigo, denominacion, tipo, descripcion, municipio_id, geom) VALUES
    ('GJ-INM-001', 'Palacio de Revillagigedo',    'inmueble', 'Edificio histórico s. XVIII, sede cultural', 1,
     ST_SetSRID(ST_MakePoint(280200, 4829800), 25830)),
    ('GJ-INM-002', 'Teatro Jovellanos',            'inmueble', 'Teatro municipal, s. XIX', 1,
     ST_SetSRID(ST_MakePoint(280500, 4829600), 25830)),
    ('GJ-INM-003', 'Mercado del Sur',              'inmueble', 'Mercado cubierto municipal', 1,
     ST_SetSRID(ST_MakePoint(280800, 4829400), 25830)),
    ('GJ-INM-004', 'Estadio El Molinón',           'inmueble', 'Estadio municipal de fútbol', 1,
     ST_SetSRID(ST_MakePoint(282100, 4829000), 25830)),
    ('GJ-INM-005', 'Palacio de Justicia',          'inmueble', 'Sede del Juzgado de Primera Instancia', 1,
     ST_SetSRID(ST_MakePoint(280600, 4830100), 25830))
ON CONFLICT (codigo) DO NOTHING;

-- ─── Aparcamientos ───────────────────────────────────────────────────────────
INSERT INTO gis.aparcamiento (nombre, tipo, plazas_total, plazas_pmr, geom) VALUES
    ('Aparcamiento Poniente',        'subterraneo', 450, 10,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((279800 4830200, 280000 4830200, 280000 4830400, 279800 4830400, 279800 4830200)))'), 25830)),
    ('Aparcamiento Jovellanos',      'subterraneo', 320,  8,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((280400 4829500, 280600 4829500, 280600 4829700, 280400 4829700, 280400 4829500)))'), 25830)),
    ('Zona C/D Muelle',              'carga_descarga', 12, 0,
     ST_SetSRID(ST_GeomFromText('MULTIPOLYGON(((280100 4830600, 280300 4830600, 280300 4830700, 280100 4830700, 280100 4830600)))'), 25830))
ON CONFLICT DO NOTHING;

-- ─── Ortofotos históricas disponibles ────────────────────────────────────────
INSERT INTO gis.ortofoto (anio, resolucion_m, url_wms, fuente) VALUES
    (1945, 1.0,  '/geoserver/ideg/wms?layers=ortofoto_1945',  'Servicio Geográfico del Ejército'),
    (1956, 0.5,  '/geoserver/ideg/wms?layers=ortofoto_1956',  'Vuelo Americano Serie B'),
    (1977, 0.5,  '/geoserver/ideg/wms?layers=ortofoto_1977',  'PNOA-H / IGN'),
    (1998, 0.25, '/geoserver/ideg/wms?layers=ortofoto_1998',  'IGN PNOA'),
    (2010, 0.25, '/geoserver/ideg/wms?layers=ortofoto_2010',  'IGN PNOA'),
    (2020, 0.25, '/geoserver/ideg/wms?layers=ortofoto_2020',  'IGN PNOA 2020')
ON CONFLICT DO NOTHING;

-- ─── Catálogo inicial de recursos IDEG ───────────────────────────────────────
INSERT INTO catalog.recurso (titulo, tipo, categoria, nivel_acceso, url_servicio, responsable_id, fecha_creacion) VALUES
    ('Cartografía base Gijón',         'servicio_wms', 'cartografia',    'publico',
     '/geoserver/ideg/wms', 'Servicio de Sistemas de Información', '2026-01-01'),
    ('Callejero municipal',             'servicio_wfs', 'cartografia',    'publico',
     '/geoserver/ideg/wfs', 'Servicio de Sistemas de Información', '2026-01-01'),
    ('Plan General de Ordenación',      'servicio_wms', 'urbanismo',      'publico',
     '/geoserver/ideg/wms', 'Servicio Técnico de Urbanismo',       '2026-01-01'),
    ('Licencias urbanísticas',          'servicio_wfs', 'urbanismo',      'interno_privado',
     '/geoserver/ideg/wfs', 'Servicio de Licencias y Disciplina',  '2026-01-01'),
    ('Inventario de bienes municipales','servicio_wms', 'patrimonio',     'interno_publico',
     '/geoserver/ideg/wms', 'Servicio de Patrimonio',              '2026-01-01'),
    ('Arbolado y zonas verdes',         'servicio_wfs', 'medio_ambiente', 'publico',
     '/geoserver/ideg/wfs', 'Servicio de Parques y Jardines',      '2026-01-01'),
    ('Aparcamientos y C/D',             'servicio_wfs', 'movilidad',      'publico',
     '/geoserver/ideg/wfs', 'Servicio de Movilidad',               '2026-01-01'),
    ('Ortofotos históricas 1945-2020',  'servicio_wmts','cartografia',    'publico',
     '/geoserver/gwc/service/wmts', 'Servicio de Sistemas de Información', '2026-01-01')
ON CONFLICT DO NOTHING;

-- Vista materializada de resumen para el visor IDEG
CREATE MATERIALIZED VIEW IF NOT EXISTS catalog.v_resumen_recursos AS
SELECT
    nivel_acceso,
    categoria,
    COUNT(*) AS total_recursos,
    COUNT(*) FILTER (WHERE activo) AS recursos_activos
FROM catalog.recurso
GROUP BY nivel_acceso, categoria
ORDER BY nivel_acceso, categoria;

CREATE UNIQUE INDEX IF NOT EXISTS idx_v_resumen_recursos
    ON catalog.v_resumen_recursos (nivel_acceso, categoria);
