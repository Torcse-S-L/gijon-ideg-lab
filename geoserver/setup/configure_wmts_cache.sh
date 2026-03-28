#!/usr/bin/env bash
# =============================================================================
# configure_wmts_cache.sh
# Configuración de cachés WMTS y Vector Tiles para capas de alta demanda
# =============================================================================
set -euo pipefail

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
GS_USER="${GEOSERVER_ADMIN_USER:-admin}"
GS_PASS="${GEOSERVER_ADMIN_PASSWORD:-geoserver}"
WORKSPACE="ideg"
GWC_API="${GEOSERVER_URL}/gwc/rest"
AUTH="-u ${GS_USER}:${GS_PASS}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

seed_layer() {
    local layer="$1"
    local zoom_start="${2:-0}"
    local zoom_stop="${3:-12}"
    local srs="${4:-EPSG:25830}"

    log "Configurando caché WMTS para '${layer}' (zoom ${zoom_start}-${zoom_stop})..."

    # Crear/actualizar configuración GWC para la capa
    curl -sf ${AUTH} -X PUT \
        "${GWC_API}/layers/${WORKSPACE}:${layer}.xml" \
        -H "Content-Type: application/xml" \
        -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<GeoServerLayer>
  <name>${WORKSPACE}:${layer}</name>
  <enabled>true</enabled>
  <mimeFormats>
    <string>image/png</string>
    <string>image/jpeg</string>
    <string>image/webp</string>
    <string>application/vnd.mapbox-vector-tile</string>
  </mimeFormats>
  <gridSubsets>
    <gridSubset>
      <gridSetName>EPSG:25830</gridSetName>
      <minCachedLevel>${zoom_start}</minCachedLevel>
      <maxCachedLevel>${zoom_stop}</maxCachedLevel>
    </gridSubset>
    <gridSubset>
      <gridSetName>EPSG:4326</gridSetName>
      <minCachedLevel>${zoom_start}</minCachedLevel>
      <maxCachedLevel>${zoom_stop}</maxCachedLevel>
    </gridSubset>
    <gridSubset>
      <gridSetName>GoogleMapsCompatible</gridSetName>
      <minCachedLevel>${zoom_start}</minCachedLevel>
      <maxCachedLevel>${zoom_stop}</maxCachedLevel>
    </gridSubset>
  </gridSubsets>
  <metaWidthHeight>
    <int>4</int>
    <int>4</int>
  </metaWidthHeight>
  <expireCache>3600</expireCache>
  <expireClients>300</expireClients>
  <parameterFilters>
    <styleParameterFilter>
      <key>STYLES</key>
      <defaultValue></defaultValue>
    </styleParameterFilter>
  </parameterFilters>
</GeoServerLayer>" || true
    log "  Caché '${layer}' configurada."
}

configure_gwc_diskquota() {
    log "Configurando cuota de disco para GeoWebCache..."
    curl -sf ${AUTH} -X PUT \
        "${GWC_API}/diskquota.xml" \
        -H "Content-Type: application/xml" \
        -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<gwcQuotaConfiguration>
  <enabled>true</enabled>
  <cacheCleanUpFrequency>10</cacheCleanUpFrequency>
  <cacheCleanUpUnits>SECONDS</cacheCleanUpUnits>
  <maxHardLimit>
    <value>20</value>
    <units>GiB</units>
  </maxHardLimit>
  <expirationPolicyName>LFU</expirationPolicyName>
</gwcQuotaConfiguration>" || true
    log "Cuota de disco GWC: 20 GiB, política LFU."
}

# ─── Ejecución ────────────────────────────────────────────────────────────────
# Capas de alta demanda (cartografía base + ortofotos): caché amplia
seed_layer "municipio"    0 14
seed_layer "callejero"    8 18
seed_layer "plan_general" 8 16
seed_layer "zonas_verdes" 8 16
seed_layer "arbolado"     10 18

# Capas temáticas: caché moderada
seed_layer "inventario_bienes"    8 14
seed_layer "aparcamiento"         10 16
seed_layer "licencia_urbanistica" 10 16

configure_gwc_diskquota

log "Configuración WMTS completada. Disco estimado total: ~8-12 GiB."
log "Para pre-generar las teselas: bash scripts/bootstrap_lab.sh --seed-cache"
