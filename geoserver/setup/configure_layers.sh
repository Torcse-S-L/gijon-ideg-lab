#!/usr/bin/env bash
# =============================================================================
# configure_layers.sh
# Auto-configuración de capas WMS/WFS en GeoServer para la IDEG de Gijón
# Requiere: curl, jq
# Uso: bash geoserver/setup/configure_layers.sh
# =============================================================================
set -euo pipefail

GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
GS_USER="${GEOSERVER_ADMIN_USER:-admin}"
GS_PASS="${GEOSERVER_ADMIN_PASSWORD:-geoserver}"
PG_HOST="${POSTGRES_HOST:-postgres}"
PG_PORT="${POSTGRES_PORT:-5432}"
PG_DB="${POSTGRES_DB:-GISDB}"
PG_USER="${POSTGRES_USER:-gisadmin}"
PG_PASS="${POSTGRES_PASSWORD:-}"
WORKSPACE="ideg"
DATASTORE="gis_postgis"

GS_API="${GEOSERVER_URL}/rest"
AUTH="-u ${GS_USER}:${GS_PASS}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

wait_geoserver() {
    log "Esperando a que GeoServer esté disponible..."
    local retries=30
    until curl -fs "${GEOSERVER_URL}/web/" > /dev/null 2>&1; do
        retries=$((retries - 1))
        [ "$retries" -le 0 ] && { echo "ERROR: GeoServer no responde"; exit 1; }
        sleep 5
    done
    log "GeoServer disponible."
}

create_workspace() {
    log "Creando workspace '${WORKSPACE}'..."
    curl -sf ${AUTH} -X POST "${GS_API}/workspaces" \
        -H "Content-Type: application/json" \
        -d "{\"workspace\":{\"name\":\"${WORKSPACE}\"}}" || true
    # Establecer como workspace por defecto
    curl -sf ${AUTH} -X PUT "${GS_API}/workspaces/${WORKSPACE}" \
        -H "Content-Type: application/json" \
        -d '{"workspace":{"default":true}}' || true
    log "Workspace '${WORKSPACE}' configurado."
}

create_datastore() {
    log "Creando datastore PostGIS '${DATASTORE}'..."
    curl -sf ${AUTH} -X POST \
        "${GS_API}/workspaces/${WORKSPACE}/datastores" \
        -H "Content-Type: application/json" \
        -d "{
            \"dataStore\": {
                \"name\": \"${DATASTORE}\",
                \"type\": \"PostGIS\",
                \"connectionParameters\": {
                    \"entry\": [
                        {\"@key\": \"host\",              \"$\": \"${PG_HOST}\"},
                        {\"@key\": \"port\",              \"$\": \"${PG_PORT}\"},
                        {\"@key\": \"database\",          \"$\": \"${PG_DB}\"},
                        {\"@key\": \"user\",              \"$\": \"${PG_USER}\"},
                        {\"@key\": \"passwd\",            \"$\": \"${PG_PASS}\"},
                        {\"@key\": \"schema\",            \"$\": \"gis\"},
                        {\"@key\": \"dbtype\",            \"$\": \"postgis\"},
                        {\"@key\": \"Expose primary keys\",\"$\": \"true\"},
                        {\"@key\": \"encode functions\",  \"$\": \"true\"},
                        {\"@key\": \"preparedStatements\",\"$\": \"true\"},
                        {\"@key\": \"max connections\",   \"$\": \"20\"},
                        {\"@key\": \"min connections\",   \"$\": \"2\"}
                    ]
                }
            }
        }" || true
    log "Datastore '${DATASTORE}' configurado."
}

publish_layer() {
    local table="$1"
    local title="$2"
    local abstract="$3"
    local srs="${4:-EPSG:25830}"

    log "Publicando capa '${table}'..."
    curl -sf ${AUTH} -X POST \
        "${GS_API}/workspaces/${WORKSPACE}/datastores/${DATASTORE}/featuretypes" \
        -H "Content-Type: application/json" \
        -d "{
            \"featureType\": {
                \"name\": \"${table}\",
                \"nativeName\": \"${table}\",
                \"title\": \"${title}\",
                \"abstract\": \"${abstract}\",
                \"srs\": \"${srs}\",
                \"enabled\": true,
                \"advertised\": true
            }
        }" || true
    log "  Capa '${table}' publicada."
}

configure_inspire_metadata() {
    log "Configurando metadatos INSPIRE en el servicio WMS..."
    curl -sf ${AUTH} -X PUT \
        "${GS_API}/services/wms/settings" \
        -H "Content-Type: application/json" \
        -d "{
            \"wms\": {
                \"enabled\": true,
                \"name\": \"IDEG Gijón — WMS\",
                \"title\": \"Infraestructura de Datos Espaciales del Ayuntamiento de Gijón/Xixón\",
                \"abstract\": \"Servicio WMS conforme a la Directiva INSPIRE. Expone las capas geoespaciales de la IDEG del Ayuntamiento de Gijón.\",
                \"keywords\": {\"string\": [\"INSPIRE\",\"WMS\",\"Gijón\",\"IDEG\",\"cartografía\"]},
                \"onlineResource\": \"https://ideg.gijon.es/geoserver/wms\",
                \"fees\": \"ninguna\",
                \"accessConstraints\": \"Condiciones de uso según normativa INSPIRE\",
                \"srs\": {\"string\": [\"EPSG:25830\",\"EPSG:4326\",\"EPSG:3857\"]}
            }
        }" || true
    log "Metadatos INSPIRE WMS configurados."
}

# ─── Ejecución ────────────────────────────────────────────────────────────────
wait_geoserver
create_workspace
create_datastore

# Publicar capas según el catálogo IDEG
publish_layer "municipio"            "Municipio de Gijón"                  "Límite municipal (ETRS89 UTM 30N)"
publish_layer "callejero"            "Callejero municipal"                  "Red viaria y callejero del municipio de Gijón"
publish_layer "plan_general"         "Plan General de Ordenación Urbana"    "PGOU vigente del Ayuntamiento de Gijón"
publish_layer "licencia_urbanistica" "Licencias urbanísticas"               "Licencias de hostelería, terrazas y VUT"
publish_layer "inventario_bienes"    "Inventario de bienes municipales"     "Bienes inmuebles del patrimonio municipal"
publish_layer "zonas_verdes"         "Zonas verdes y parques"               "Parques, jardines y áreas recreativas"
publish_layer "arbolado"             "Inventario de arbolado"               "Árboles inventariados en el municipio"
publish_layer "aparcamiento"         "Aparcamientos y zonas C/D"            "Aparcamientos públicos y zonas de carga/descarga"

configure_inspire_metadata

log "Auto-configuración de GeoServer completada."
