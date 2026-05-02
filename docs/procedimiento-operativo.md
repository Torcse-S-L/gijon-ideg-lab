# Procedimiento Operativo — IDEG Gijón

## Backup y Restore

### Backup manual

```bash
# Backup completo (PostgreSQL + GeoServer data_dir)
bash scripts/backup_restore.sh backup

# Backup en directorio personalizado
bash scripts/backup_restore.sh backup --target /mnt/backups/ideg
```

### Backup automático (pg_cron)

El siguiente job se instala en PostgreSQL para backup diario a las 03:00:

```sql
SELECT cron.schedule(
    'backup-diario-ideg',
    '0 3 * * *',
    $$SELECT pg_dump_to_file('/var/backups/gisdb_' || to_char(now(),'YYYYMMDD') || '.dump')$$
);
```

### Restore

```bash
# Restore desde el último backup disponible
bash scripts/backup_restore.sh restore

# Restore desde fichero específico
bash scripts/backup_restore.sh restore --target /mnt/backups/ideg
```

**Retención:** 7 copias diarias + 4 copias semanales (domingo) + 12 copias mensuales.

---

## Actualización de componentes

### PostgreSQL

```bash
# 1. Backup previo
bash scripts/backup_restore.sh backup

# 2. Parar servicios dependientes
docker compose stop geoserver geonetwork qgis-server

# 3. Actualizar con pg_upgrade
docker compose pull postgres
docker compose up -d postgres

# 4. Verificar
docker compose exec postgres psql -U gisadmin -d GISDB -c "SELECT version();"

# 5. Levantar el resto
docker compose up -d
```

### GeoServer

Las actualizaciones de GeoServer deben planificarse en horario de baja carga (madrugada). El `data_dir` se persiste en volumen Docker, por lo que la actualización no afecta a la configuración.

```bash
# 1. Backup del data_dir
bash scripts/backup_restore.sh backup

# 2. Cambiar la versión en docker-compose.yml
# imagen: kartoza/geoserver:2.25.2 → kartoza/geoserver:2.26.x

# 3. Recrear el contenedor
docker compose up -d --force-recreate geoserver

# 4. Verificar plugins y configuración
bash geoserver/setup/configure_layers.sh
bash tests/test_ogc_services.sh
```

---

## Gestión de seguridad

### Rotación de credenciales

```bash
# Cambiar contraseña PostgreSQL
docker compose exec postgres psql -U gisadmin -d GISDB \
    -c "ALTER USER gisadmin PASSWORD 'nueva_password';"

# Actualizar .env y reiniciar
# Editar .env → POSTGRES_PASSWORD=nueva_password
docker compose restart geoserver geonetwork
```

### Certificado SSL (Apache)

```bash
# Renovación automática Let's Encrypt
certbot renew --pre-hook "docker compose stop mapstore" \
              --post-hook "docker compose start mapstore"

# Verificar fecha de caducidad
openssl x509 -enddate -noout -in /etc/letsencrypt/live/ideg.gijon.es/cert.pem
```

### Control de acceso VPN

Todo acceso externo al entorno de producción se realiza exclusivamente a través de VPN. El adjudicatario registra en el siguiente formulario cada acceso:

| Campo | Descripción |
|-------|-------------|
| Empleado | Nombre y DNI |
| Fecha/hora de conexión | ISO 8601 |
| Motivo de la conexión | Tarea concreta |
| Componentes accedidos | GeoServer, PostgreSQL, etc. |
| Fecha/hora de desconexión | ISO 8601 |

---

## Matriz de incidencias y escalado

| Nivel | Descripción | Tiempo respuesta | Canal |
|-------|-------------|-----------------|-------|
| 🔴 P1 — Crítico | Servicio IDEG completamente caído (producción) | < 1h | Teléfono + email urgente |
| 🟠 P2 — Alto | Capa OGC individual caída o rendimiento > 15s | < 4h | Email + ticketing |
| 🟡 P3 — Medio | Rendimiento degradado (5-15s) o error en catálogo | < 12h | Ticketing |
| 🟢 P4 — Bajo | Mejora, tarea planificada, actualización | Planificado | Ticketing |

### Procedimiento P1

1. Verificar estado del stack: `docker compose ps`
2. Revisar logs del componente afectado: `docker compose logs --tail 100 <servicio>`
3. Comprobar recursos del host: `free -h && df -h && uptime`
4. Si el componente no arranca → restaurar desde último backup
5. Comunicar incidente al responsable del contrato del Ayuntamiento
6. Documentar causa raíz y medidas correctoras

---

## Tareas de mantenimiento periódico

| Frecuencia | Tarea |
|-----------|-------|
| Diaria | Backup automático PostgreSQL |
| Diaria | Verificación alertas Grafana |
| Semanal | Revisión logs de acceso Kibana |
| Mensual | Vacuum y analyze de tablas principales |
| Mensual | Revisión espacio en disco y cachés WMTS |
| Trimestral | Actualización de componentes (planificada) |
| Anual | Revisión y renovación certificados SSL |
| Anual | Auditoría de usuarios y permisos GeoNetwork |
