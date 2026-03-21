-- =============================================================================
-- 002_compat_views.sql
-- Vistas de compatibilidad para herramientas GIS legadas (SITMAP, plugin QGIS EIEL)
-- Exponen la misma forma que el modelo anterior para no romper aplicaciones.
-- =============================================================================

SET search_path = compat, gis, public;

-- Vista compatibilidad: callejero simplificado
CREATE OR REPLACE VIEW compat.v_callejero AS
SELECT
    c.id,
    c.via_id      AS cod_via,
    c.tipo_via,
    c.nombre      AS nombre_via,
    c.nombre_ast,
    m.nombre      AS municipio,
    m.codigo_ine,
    c.geom,
    c.fecha_act
FROM gis.callejero c
JOIN gis.municipio m ON m.id = c.municipio_id;

COMMENT ON VIEW compat.v_callejero IS 'Compatibilidad: callejero con datos de municipio aplanados';

-- Vista compatibilidad: capas de urbanismo unificadas
CREATE OR REPLACE VIEW compat.v_urbanismo AS
SELECT
    'plan_general'      AS tipo_capa,
    id::TEXT            AS id_objeto,
    clasificacion       AS atributo_principal,
    calificacion        AS atributo_secundario,
    geom,
    fecha_act
FROM gis.plan_general WHERE vigente = true
UNION ALL
SELECT
    'licencia'          AS tipo_capa,
    id::TEXT,
    tipo,
    estado,
    geom::GEOMETRY,
    fecha_act
FROM gis.licencia_urbanistica;

COMMENT ON VIEW compat.v_urbanismo IS 'Compatibilidad: datos urbanísticos unificados para visores legados';

-- Vista compatibilidad: inventario bienes
CREATE OR REPLACE VIEW compat.v_inventario_bienes AS
SELECT
    b.id,
    b.codigo,
    b.denominacion,
    b.tipo,
    b.descripcion,
    m.nombre        AS municipio,
    b.valor_catastral,
    b.geom,
    b.fecha_alta,
    b.fecha_act
FROM gis.inventario_bienes b
LEFT JOIN gis.municipio m ON m.id = b.municipio_id;

COMMENT ON VIEW compat.v_inventario_bienes IS 'Compatibilidad: inventario de bienes con datos de municipio';

-- Vista compatibilidad: medio ambiente
CREATE OR REPLACE VIEW compat.v_medio_ambiente AS
SELECT
    'zona_verde'    AS tipo,
    z.id::TEXT,
    z.nombre,
    z.tipo          AS subtipo,
    z.superficie_m2 AS magnitud,
    z.geom::GEOMETRY,
    z.fecha_act
FROM gis.zonas_verdes z
UNION ALL
SELECT
    'arbol'         AS tipo,
    a.id::TEXT,
    COALESCE(a.nombre_comun, a.especie) AS nombre,
    a.estado        AS subtipo,
    a.altura_m      AS magnitud,
    a.geom::GEOMETRY,
    a.fecha_act
FROM gis.arbolado a;

COMMENT ON VIEW compat.v_medio_ambiente IS 'Compatibilidad: datos medioambientales unificados';

-- Vista pública para el visor IDEG (Sede Electrónica) — solo nivel público
CREATE OR REPLACE VIEW compat.v_recursos_publicos AS
SELECT
    r.id,
    r.titulo,
    r.descripcion,
    r.tipo,
    r.categoria,
    r.url_servicio,
    r.fecha_creacion
FROM catalog.recurso r
WHERE r.nivel_acceso = 'publico' AND r.activo = true
ORDER BY r.categoria, r.titulo;

COMMENT ON VIEW compat.v_recursos_publicos IS 'Catálogo de recursos públicos expuestos en la Sede Electrónica';
