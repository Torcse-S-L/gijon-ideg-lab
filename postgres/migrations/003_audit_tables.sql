-- =============================================================================
-- 003_audit_tables.sql
-- Tablas de auditoría: accesos a servicios OGC y cambios de datos
-- =============================================================================

SET search_path = audit, public;

-- ─── Accesos a servicios OGC ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit.ogc_access_log (
    id              BIGSERIAL PRIMARY KEY,
    ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
    servicio        TEXT NOT NULL,   -- WMS, WFS, WMTS, WCS, CSW
    capa            TEXT,
    operacion       TEXT,            -- GetMap, GetFeature, GetCapabilities…
    ip_origen       INET,
    usuario         TEXT,            -- 'anonimo' si no autenticado
    nivel_acceso    TEXT,
    tiempo_ms       INTEGER,
    http_status     SMALLINT,
    bytes_enviados  BIGINT,
    bbox            TEXT,
    srs             TEXT
) PARTITION BY RANGE (ts);

-- Particiones mensuales automáticas (pg_cron gestiona la creación futura)
CREATE TABLE IF NOT EXISTS audit.ogc_access_log_2026_03
    PARTITION OF audit.ogc_access_log
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE IF NOT EXISTS audit.ogc_access_log_2026_04
    PARTITION OF audit.ogc_access_log
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE IF NOT EXISTS audit.ogc_access_log_2026_05
    PARTITION OF audit.ogc_access_log
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE INDEX IF NOT EXISTS idx_audit_ts      ON audit.ogc_access_log(ts);
CREATE INDEX IF NOT EXISTS idx_audit_capa    ON audit.ogc_access_log(capa);
CREATE INDEX IF NOT EXISTS idx_audit_usuario ON audit.ogc_access_log(usuario);

-- ─── Cambios en datos geoespaciales ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit.data_change_log (
    id              BIGSERIAL PRIMARY KEY,
    ts              TIMESTAMPTZ NOT NULL DEFAULT now(),
    esquema         TEXT NOT NULL,
    tabla           TEXT NOT NULL,
    operacion       TEXT NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    id_registro     TEXT,
    usuario_db      TEXT DEFAULT current_user,
    datos_anteriores JSONB,
    datos_nuevos    JSONB
);

CREATE INDEX IF NOT EXISTS idx_change_ts     ON audit.data_change_log(ts);
CREATE INDEX IF NOT EXISTS idx_change_tabla  ON audit.data_change_log(esquema, tabla);

-- Función genérica de auditoría de cambios
CREATE OR REPLACE FUNCTION audit.fn_log_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit.data_change_log(esquema, tabla, operacion, id_registro,
                                       datos_anteriores, datos_nuevos)
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP = 'DELETE' THEN (row_to_json(OLD)->>'id') ELSE (row_to_json(NEW)->>'id') END,
        CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN row_to_json(OLD)::JSONB ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN row_to_json(NEW)::JSONB ELSE NULL END
    );
    RETURN NULL;
END;
$$;

-- Aplicar trigger de auditoría a tablas principales
DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY['gis.callejero','gis.plan_general',
                              'gis.licencia_urbanistica','gis.inventario_bienes',
                              'catalog.recurso']
    LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_audit_%s
             AFTER INSERT OR UPDATE OR DELETE ON %s
             FOR EACH ROW EXECUTE FUNCTION audit.fn_log_change()',
            replace(t, '.', '_'), t
        );
    END LOOP;
EXCEPTION WHEN duplicate_object THEN NULL;
END;
$$;

-- ─── Vista de resumen de auditoría (para Kibana / Grafana) ───────────────────
CREATE OR REPLACE VIEW audit.v_accesos_diarios AS
SELECT
    date_trunc('day', ts)::DATE AS dia,
    servicio,
    COUNT(*)                    AS total_peticiones,
    COUNT(*) FILTER (WHERE http_status >= 400) AS errores,
    AVG(tiempo_ms)::INTEGER     AS latencia_media_ms,
    COUNT(DISTINCT ip_origen)   AS ips_unicas
FROM audit.ogc_access_log
WHERE ts >= now() - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

COMMENT ON VIEW audit.v_accesos_diarios IS 'Resumen diario de accesos OGC (últimos 30 días)';
