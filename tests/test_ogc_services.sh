#!/usr/bin/env bash
# =============================================================================
# test_ogc_services.sh
# Tests de servicios OGC: GetMap, GetFeature, GetTile
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

GS_URL="http://localhost:${GEOSERVER_PORT:-8080}/geoserver"
PASS=0; FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1 — $2"; FAIL=$((FAIL+1)); }

assert_image() {
    local desc="$1"; local url="$2"
    local code
    code=$(curl -s -o /tmp/ideg_test_img.tmp -w "%{http_code}" --max-time 20 "${url}" 2>/dev/null || echo "000")
    local ctype
    ctype=$(file /tmp/ideg_test_img.tmp 2>/dev/null | grep -i "PNG\|JPEG\|image" || echo "")
    if [ "${code}" = "200" ] && [ -n "${ctype}" ]; then
        ok "${desc}"
    else
        fail "${desc}" "HTTP ${code} / tipo: ${ctype:-desconocido}"
    fi
}

assert_geojson() {
    local desc="$1"; local url="$2"; local expected_feature="$3"
    local body
    body=$(curl -s --max-time 15 "${url}" 2>/dev/null || echo "")
    if echo "${body}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('totalFeatures',d.get('numberMatched',0)) > 0" 2>/dev/null; then
        ok "${desc}"
    else
        fail "${desc}" "Sin features en GeoJSON"
    fi
}

echo ""
echo "══════════════════════════════════════════════════════"
echo "  IDEG Gijón — Tests servicios OGC"
echo "══════════════════════════════════════════════════════"

# ── WMS GetMap ────────────────────────────────────────────────────────────────
BBOX="272000,4824000,290000,4836000"
echo ""
echo "▶ WMS — GetMap (EPSG:25830)"
assert_image "GetMap municipio 256x256" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=ideg:municipio&STYLES=&CRS=EPSG:25830&BBOX=${BBOX}&WIDTH=256&HEIGHT=256&FORMAT=image/png"
assert_image "GetMap plan_general" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=ideg:plan_general&STYLES=&CRS=EPSG:25830&BBOX=${BBOX}&WIDTH=256&HEIGHT=256&FORMAT=image/png"
assert_image "GetMap zonas_verdes" \
    "${GS_URL}/ideg/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=ideg:zonas_verdes&STYLES=&CRS=EPSG:25830&BBOX=${BBOX}&WIDTH=256&HEIGHT=256&FORMAT=image/png"

# ── WFS GetFeature ────────────────────────────────────────────────────────────
echo ""
echo "▶ WFS — GetFeature"
assert_geojson "GetFeature municipio (GeoJSON)" \
    "${GS_URL}/ideg/wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ideg:municipio&OUTPUTFORMAT=application/json&COUNT=10" \
    "municipio"
assert_geojson "GetFeature inventario_bienes" \
    "${GS_URL}/ideg/wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ideg:inventario_bienes&OUTPUTFORMAT=application/json&COUNT=10" \
    "bienes"

# ── WMTS GetTile ──────────────────────────────────────────────────────────────
echo ""
echo "▶ WMTS — GetTile"
assert_image "WMTS tile municipio zoom 4" \
    "${GS_URL}/gwc/service/wmts?REQUEST=GetTile&SERVICE=WMTS&VERSION=1.0.0&LAYER=ideg:municipio&STYLE=&TILEMATRIXSET=EPSG:25830&TILEMATRIX=EPSG:25830:4&TILEROW=10&TILECOL=12&FORMAT=image/png"

echo ""
echo "══════════════════════════════════════════════════════"
printf "  Resultado: %d PASS  /  %d FAIL\n" "${PASS}" "${FAIL}"
echo "══════════════════════════════════════════════════════"
echo ""
[ "${FAIL}" -eq 0 ]
