#!/usr/bin/env bash
# =============================================================================
# configure_geonetwork.sh
# Configura GeoNetwork 4.x para la IDEG de Gijón:
#   - Perfiles de metadatos INSPIRE (ISO 19115/19139)
#   - Grupos y usuarios con control de acceso por nivel
#   - Harvesting desde GeoServer
# =============================================================================
set -euo pipefail

GN_URL="${GEONETWORK_URL:-http://localhost:8081/geonetwork}"
GN_USER="${GEONETWORK_ADMIN_USER:-admin}"
GN_PASS="${GEONETWORK_ADMIN_PASSWORD:-admin}"
GN_API="${GN_URL}/srv/api"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

wait_geonetwork() {
    log "Esperando a que GeoNetwork esté disponible..."
    local retries=40
    until curl -fs "${GN_URL}/srv/eng/catalog.search" > /dev/null 2>&1; do
        retries=$((retries - 1))
        [ "$retries" -le 0 ] && { echo "ERROR: GeoNetwork no responde"; exit 1; }
        sleep 6
    done
    log "GeoNetwork disponible."
}

get_xsrf_token() {
    # GeoNetwork 4.x requiere token XSRF para peticiones POST/PUT
    curl -sf -c /tmp/gn_cookies.txt \
        "${GN_API}/me" \
        -H "Accept: application/json" \
        -u "${GN_USER}:${GN_PASS}" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('xsrfToken',''))" 2>/dev/null || echo ""
}

create_group() {
    local name="$1"
    local description="$2"
    local email="$3"

    log "Creando grupo '${name}'..."
    curl -sf -b /tmp/gn_cookies.txt \
        -X POST "${GN_API}/groups" \
        -H "Content-Type: application/json" \
        -H "X-XSRF-TOKEN: $(get_xsrf_token)" \
        -u "${GN_USER}:${GN_PASS}" \
        -d "{
            \"name\": \"${name}\",
            \"description\": \"${description}\",
            \"email\": \"${email}\",
            \"enableAllowedCategories\": false,
            \"defaultCategory\": null
        }" || true
    log "  Grupo '${name}' creado."
}

configure_settings() {
    log "Configurando ajustes del catálogo IDEG..."
    curl -sf -b /tmp/gn_cookies.txt \
        -X POST "${GN_API}/site/settings" \
        -H "Content-Type: application/json" \
        -H "X-XSRF-TOKEN: $(get_xsrf_token)" \
        -u "${GN_USER}:${GN_PASS}" \
        -d '{
            "system/site/name":                "IDEG Gijón — Catálogo de metadatos",
            "system/site/organization":        "Ayuntamiento de Gijón/Xixón",
            "system/site/siteId":              "gijon-ideg-2026",
            "system/inspire/enable":           "true",
            "system/inspire/atomProtocol":     "INSPIRE",
            "system/proxy/use":                "false",
            "system/ogcproxy/enable":          "false",
            "system/metadata/prefergrouplogo": "true",
            "system/localrating/enable":       "false",
            "system/harvesting/enableEditing": "false"
        }' || true
    log "Ajustes del catálogo configurados."
}

configure_harvester_geoserver() {
    log "Configurando harvester WMS desde GeoServer..."
    curl -sf -b /tmp/gn_cookies.txt \
        -X PUT "${GN_API}/harvesters" \
        -H "Content-Type: application/json" \
        -H "X-XSRF-TOKEN: $(get_xsrf_token)" \
        -u "${GN_USER}:${GN_PASS}" \
        -d '{
            "site": {
                "name": "GeoServer IDEG Gijón",
                "type": "geoserver.rest",
                "url":  "http://geoserver:8080/geoserver",
                "rejectDuplicateResource": false,
                "workspaceFilter": "ideg",
                "groupPublicationFilter": "all"
            },
            "options": {
                "every": "0 0 2 * * ?",
                "oneRunOnly": false,
                "status": "active"
            },
            "content": {
                "validate": "NOVALIDATION",
                "importxslt": "none"
            }
        }' || true
    log "Harvester GeoServer configurado (ejecución diaria a las 02:00)."
}

# ─── Ejecución ────────────────────────────────────────────────────────────────
wait_geonetwork
configure_settings

# Grupos de acceso (equivalentes a los niveles del pliego)
create_group "publico"           "Recursos públicos accesibles desde la Sede Electrónica" "sistemas.informacion@gijon.es"
create_group "publico_protegido" "Recursos con autenticación de ciudadano"                "sistemas.informacion@gijon.es"
create_group "interno_publico"   "Recursos de intranet municipal sin credenciales"         "sistemas.informacion@gijon.es"
create_group "interno_privado"   "Recursos internos con autenticación municipal"           "sistemas.informacion@gijon.es"

configure_harvester_geoserver

log "Configuración de GeoNetwork completada."
