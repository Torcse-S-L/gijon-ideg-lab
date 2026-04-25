#!/usr/bin/env bash
# =============================================================================
# backup_restore.sh
# Backup y restore de PostgreSQL/PostGIS y GeoServer para la IDEG de Gijón
# Uso: bash scripts/backup_restore.sh [backup|restore] [--target <dir>]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
BACKUP_DIR="${PROJECT_DIR}/backups"
ACTION="${1:-backup}"
TARGET_DIR="${BACKUP_DIR}"

# Procesar argumentos opcionales
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) TARGET_DIR="$2"; shift 2 ;;
        *) echo "Argumento desconocido: $1"; exit 1 ;;
    esac
done

[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

PG_HOST="${POSTGRES_HOST:-localhost}"
PG_PORT="${POSTGRES_PORT:-5432}"
PG_DB="${POSTGRES_DB:-GISDB}"
PG_USER="${POSTGRES_USER:-gisadmin}"
TS="$(date '+%Y%m%d_%H%M%S')"

log()    { echo "[$(date '+%H:%M:%S')] $*"; }
log_ok() { echo "[$(date '+%H:%M:%S')] ✓ $*"; }

# ── BACKUP ────────────────────────────────────────────────────────────────────
do_backup() {
    mkdir -p "${TARGET_DIR}"
    local backup_file="${TARGET_DIR}/gisdb_${TS}.sql.gz"
    local gs_backup="${TARGET_DIR}/geoserver_datadir_${TS}.tar.gz"

    log "Backup PostgreSQL → ${backup_file}"
    PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
        -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" \
        --no-password --format=custom \
        | gzip > "${backup_file}"
    log_ok "Backup BD: $(du -sh "${backup_file}" | cut -f1)"

    log "Backup GeoServer data_dir → ${gs_backup}"
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" \
        exec -T geoserver \
        tar czf - /opt/geoserver/data_dir 2>/dev/null \
        > "${gs_backup}" || true
    log_ok "Backup GeoServer: $(du -sh "${gs_backup}" | cut -f1)"

    # Mantener solo los 7 backups más recientes
    log "Rotando backups (manteniendo últimos 7)..."
    ls -t "${TARGET_DIR}"/gisdb_*.sql.gz 2>/dev/null | tail -n +8 | xargs rm -f || true
    ls -t "${TARGET_DIR}"/geoserver_*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f || true

    log_ok "Backup completado en ${TARGET_DIR}"
}

# ── RESTORE ───────────────────────────────────────────────────────────────────
do_restore() {
    local latest_db
    latest_db="$(ls -t "${TARGET_DIR}"/gisdb_*.sql.gz 2>/dev/null | head -1)"
    if [ -z "${latest_db}" ]; then
        echo "ERROR: No se encontró ningún backup en ${TARGET_DIR}"; exit 1
    fi

    log "Restaurando backup: ${latest_db}"
    read -r -p "¿Confirmas restaurar sobre ${PG_DB}? Esto borrará los datos actuales. [s/N] " confirm
    [[ "${confirm}" =~ ^[sS]$ ]] || { log "Cancelado."; exit 0; }

    PGPASSWORD="${POSTGRES_PASSWORD}" pg_restore \
        -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" \
        --no-password --clean --if-exists \
        <(gunzip -c "${latest_db}")
    log_ok "Base de datos restaurada desde ${latest_db}"
}

case "${ACTION}" in
    backup)  do_backup  ;;
    restore) do_restore ;;
    *) echo "Uso: $0 [backup|restore] [--target <dir>]"; exit 1 ;;
esac
