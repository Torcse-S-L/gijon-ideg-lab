#!/usr/bin/env bash
# =============================================================================
# test_ideg_e2e.sh
# Suite de tests e2e del stack IDEG de Gijón
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

GS_URL="http://localhost:${GEOSERVER_PORT:-8080}/geoserver"
GN_URL="http://localhost:${GEONETWORK_PORT:-8081}/geonetwork"
PG_HOST="${POSTGRES_HOST:-localhost}"
PG_PORT="${POSTGRES_PORT:-5432}"
PG_DB="${POSTGRES_DB:-GISDB}"
PG_USER="${POSTGRES_USER:-gisadmin}"

PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1 — $2"; FAIL=$((FAIL+1)); }

assert_http() {
    local desc="$1"
    local url="$2"
    local expected_code="${3:-200}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}" 2>/dev/null || echo "000")
    if [ "${code}" = "${expected_code}" ]; then
        ok "${desc} (HTTP ${code})"
    else
        fail "${desc}" "HTTP ${code} (esperado ${expected_code})"
    fi
}

assert_contains() {
    local desc="$1"
    local url="$2"
    local pattern="$3"
    local body
    body=$(curl -s --max-time 15 "${url}" 2>/dev/null || echo "")
    if echo "${body}" | grep -qi "${pattern}"; then
        ok "${desc}"
    else
        fail "${desc}" "No se encontró '${pattern}' en la respuesta"
    fi
}

assert_sql() {
    local desc="$1"
    local query="$2"
    local expected="$3"
    local result
    result=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" -tAq -c "${query}" 2>/dev/null || echo "ERROR")
    if [ "${result}" = "${expected}" ]; then
        ok "${desc}"
    else
        fail "${desc}" "Resultado: '${result}' (esperado '${expected}')"
    fi
}

echo ""
echo "══════════════════════════════════════════════════════"
echo "  IDEG Gijón — Suite de Tests e2e"
echo "══════════════════════════════════════════════════════"

# ── PostgreSQL/PostGIS ────────────────────────────────────────────────────────
echo ""
echo "▶ PostgreSQL / PostGIS"
assert_sql "PostGIS activado" \
    "SELECT COUNT(*) FROM pg_extension WHERE extname='postgis';" "1"
assert_sql "Esquema gis existe" \
    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='gis';" "1"
assert_sql "Esquema inspire existe" \
    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='inspire';" "1"
assert_sql "Esquema audit existe" \
    "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='audit';" "1"
assert_sql "Municipio de Gijón cargado" \
    "SELECT codigo_ine FROM gis.municipio WHERE codigo_ine='33024';" "33024"
assert_sql "Recursos en catálogo > 0" \
    "SELECT COUNT(*) > 0 FROM catalog.recurso;" "t"
assert_sql "Vista compat.v_recursos_publicos accesible" \
    "SELECT COUNT(*) >= 0 FROM compat.v_recursos_publicos;" "t"

# ── GeoServer ─────────────────────────────────────────────────────────────────
echo ""
echo "▶ GeoServer — WMS"
assert_http "GeoServer web" "${GS_URL}/web/" 200
assert_contains "WMS GetCapabilities" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" \
    "WMS_Capabilities"
assert_contains "WFS GetCapabilities" \
    "${GS_URL}/ideg/wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" \
    "WFS_Capabilities"
assert_contains "WMTS GetCapabilities" \
    "${GS_URL}/gwc/service/wmts?REQUEST=GetCapabilities" \
    "Capabilities"
assert_contains "Capa municipio en WMS" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" \
    "municipio"
assert_contains "Capa callejero en WMS" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" \
    "callejero"

# ── GeoNetwork ────────────────────────────────────────────────────────────────
echo ""
echo "▶ GeoNetwork — CSW / INSPIRE"
assert_http "GeoNetwork web" "${GN_URL}/srv/eng/catalog.search" 200
assert_contains "CSW GetCapabilities" \
    "${GN_URL}/srv/eng/csw?SERVICE=CSW&VERSION=2.0.2&REQUEST=GetCapabilities" \
    "Capabilities"
assert_contains "INSPIRE habilitado en GeoNetwork" \
    "${GN_URL}/srv/api/site" \
    "IDEG"

# ── Prometheus ────────────────────────────────────────────────────────────────
echo ""
echo "▶ Prometheus"
assert_http "Prometheus UI" \
    "http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy" 200
assert_contains "Reglas de alertas cargadas" \
    "http://localhost:${PROMETHEUS_PORT:-9090}/api/v1/rules" \
    "ideg_gis_alerts"

# ── Grafana ───────────────────────────────────────────────────────────────────
echo ""
echo "▶ Grafana"
assert_http "Grafana health" \
    "http://localhost:${GRAFANA_PORT:-3000}/api/health" 200

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
printf "  Resultado: %d PASS  /  %d FAIL\n" "${PASS}" "${FAIL}"
echo "══════════════════════════════════════════════════════"
echo ""

[ "${FAIL}" -eq 0 ]
