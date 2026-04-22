#!/usr/bin/env bash
# =============================================================================
# run_migrations.sh
# Aplica las migraciones SQL de la IDEG sobre PostgreSQL/PostGIS
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
MIGRATIONS_DIR="${PROJECT_DIR}/postgres/migrations"

# Cargar variables de entorno si existen
[ -f "${PROJECT_DIR}/.env" ] && source "${PROJECT_DIR}/.env"

PG_HOST="${POSTGRES_HOST:-localhost}"
PG_PORT="${POSTGRES_PORT:-5432}"
PG_DB="${POSTGRES_DB:-GISDB}"
PG_USER="${POSTGRES_USER:-gisadmin}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Tabla de control de migraciones aplicadas
ensure_migration_table() {
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" -q \
        -c "CREATE TABLE IF NOT EXISTS public.schema_migrations (
                id        SERIAL PRIMARY KEY,
                filename  TEXT NOT NULL UNIQUE,
                applied_at TIMESTAMPTZ DEFAULT now()
            );"
}

apply_migration() {
    local file="$1"
    local filename
    filename="$(basename "${file}")"

    # Verificar si ya fue aplicada
    local already
    already=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" -tAq \
        -c "SELECT COUNT(*) FROM public.schema_migrations WHERE filename = '${filename}';")

    if [ "${already}" -gt 0 ]; then
        log "  [skip] ${filename} ya aplicada."
        return
    fi

    log "  [apply] ${filename}..."
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" -q -f "${file}"

    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${PG_HOST}" -p "${PG_PORT}" \
        -U "${PG_USER}" -d "${PG_DB}" -q \
        -c "INSERT INTO public.schema_migrations (filename) VALUES ('${filename}') ON CONFLICT DO NOTHING;"

    log "    ✓ ${filename} aplicada."
}

log "Aplicando migraciones en ${PG_DB}@${PG_HOST}:${PG_PORT}..."
ensure_migration_table

for migration_file in "${MIGRATIONS_DIR}"/[0-9]*.sql; do
    [ -f "${migration_file}" ] && apply_migration "${migration_file}"
done

log "Migraciones completadas."
