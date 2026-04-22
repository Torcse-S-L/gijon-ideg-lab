#!/usr/bin/env bash
# =============================================================================
# bootstrap_lab.sh
# Inicialización completa del entorno de laboratorio IDEG Gijón
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
SEED_CACHE=false

usage() {
    echo "Uso: $0 [--seed-cache]"
    echo "  --seed-cache   Pre-generar cachés WMTS (requiere tiempo adicional)"
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --seed-cache) SEED_CACHE=true ;;
        --help|-h) usage ;;
        *) echo "Argumento desconocido: $arg"; usage ;;
    esac
done

log() { echo "[$(date '+%H:%M:%S')] $*"; }
log_ok()  { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
log_err() { echo "[$(date '+%H:%M:%S')] ✗ ERROR: $*" >&2; }

# ── Verificar dependencias ────────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in docker curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_err "Dependencias faltantes: ${missing[*]}"
        exit 1
    fi
    docker compose version &>/dev/null || { log_err "docker compose v2 requerido"; exit 1; }
}

# ── Verificar .env ────────────────────────────────────────────────────────────
check_env() {
    if [ ! -f "${PROJECT_DIR}/.env" ]; then
        log "Fichero .env no encontrado. Copiando .env.example..."
        cp "${PROJECT_DIR}/.env.example" "${PROJECT_DIR}/.env"
        log_err "Por favor edita ${PROJECT_DIR}/.env antes de continuar."
        exit 1
    fi
    # Cargar variables
    set -o allexport
    # shellcheck source=/dev/null
    source "${PROJECT_DIR}/.env"
    set +o allexport
}

# ── Levantar stack ────────────────────────────────────────────────────────────
start_stack() {
    log "Levantando stack Docker Compose..."
    cd "${PROJECT_DIR}"
    docker compose up -d postgres
    log "Esperando a que PostgreSQL esté sano..."
    docker compose exec -T postgres \
        bash -c "until pg_isready -U \${POSTGRES_USER} -d \${POSTGRES_DB}; do sleep 2; done"
    log_ok "PostgreSQL disponible."

    log "Aplicando migraciones SQL..."
    bash "${SCRIPT_DIR}/run_migrations.sh"
    log_ok "Migraciones aplicadas."

    log "Levantando resto del stack..."
    docker compose up -d
    log_ok "Stack completo levantado."
}

# ── Configurar GeoServer ──────────────────────────────────────────────────────
configure_geoserver() {
    log "Configurando GeoServer (esperando a que arranque)..."
    bash "${PROJECT_DIR}/geoserver/setup/configure_layers.sh"
    bash "${PROJECT_DIR}/geoserver/setup/configure_wmts_cache.sh"
    log_ok "GeoServer configurado."
}

# ── Configurar GeoNetwork ─────────────────────────────────────────────────────
configure_geonetwork() {
    log "Configurando GeoNetwork INSPIRE..."
    bash "${PROJECT_DIR}/geonetwork/setup/configure_geonetwork.sh"
    log_ok "GeoNetwork configurado."
}

# ── Pre-generar cachés ────────────────────────────────────────────────────────
seed_wmts_cache() {
    if [ "${SEED_CACHE}" = true ]; then
        log "Pre-generando cachés WMTS (zoom 0-10)... esto puede tardar varios minutos."
        local GS_URL="http://localhost:${GEOSERVER_PORT:-8080}/geoserver"
        local AUTH="${GEOSERVER_ADMIN_USER:-admin}:${GEOSERVER_ADMIN_PASSWORD}"
        for layer in municipio callejero plan_general zonas_verdes; do
            log "  Seeding capa: ideg:${layer} (zoom 0-10)"
            curl -sf -u "${AUTH}" -X POST \
                "${GS_URL}/gwc/rest/seed/ideg:${layer}.json" \
                -H "Content-Type: application/json" \
                -d "{\"seedRequest\":{\"name\":\"ideg:${layer}\",\"gridSetId\":\"EPSG:25830\",
                    \"zoomStart\":0,\"zoomStop\":10,\"type\":\"seed\",\"threadCount\":2}}" || true
        done
        log_ok "Cachés WMTS en proceso de generación (background)."
    fi
}

# ── Resumen final ─────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo "══════════════════════════════════════════════════════"
    echo "  IDEG Gijón Lab — Stack levantado correctamente"
    echo "══════════════════════════════════════════════════════"
    echo "  Visor IDEG:    http://localhost:${MAPSTORE_PORT:-80}/ideg"
    echo "  GeoServer:     http://localhost:${GEOSERVER_PORT:-8080}/geoserver"
    echo "  GeoNetwork:    http://localhost:${GEONETWORK_PORT:-8081}/geonetwork"
    echo "  QGIS Server:   http://localhost:${QGIS_SERVER_PORT:-8082}/qgis/"
    echo "  Grafana:       http://localhost:${GRAFANA_PORT:-3000}"
    echo "  Prometheus:    http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  Kibana:        http://localhost:${KIBANA_PORT:-5601}"
    echo "  PostgreSQL:    localhost:${POSTGRES_PORT:-5432}/${POSTGRES_DB:-GISDB}"
    echo "══════════════════════════════════════════════════════"
    echo "  Tests: bash tests/test_ideg_e2e.sh"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
check_deps
check_env
start_stack
configure_geoserver
configure_geonetwork
seed_wmts_cache
print_summary
