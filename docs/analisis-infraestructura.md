# Análisis de la Infraestructura GIS Existente

## Diagnóstico por servidor

### Servidor Geonetwork (Ubuntu 20.04)

**Estado actual:**
- PostgreSQL 12 con BD `GISDB`: todos los geodatos en esquema único, sin separación por dominio
- GeoNetwork 4.0.5 instalado pero **sin configurar ni en producción**
- Tomcat 9.0.50 detrás de Apache (AJP) — configuración básica sin tunning

**Hallazgos:**
| # | Área | Hallazgo | Severidad |
|---|------|----------|-----------|
| 1 | PostgreSQL | Versión 12 EOL (nov. 2024). Actualizar a 16 | Alta |
| 2 | PostgreSQL | `shared_buffers` al 12.5% (1 GB). Subir a 4 GB (25% de 16 GB) | Alta |
| 3 | PostgreSQL | `work_mem` no configurado (4 MB defecto). Subir a 64 MB para consultas espaciales | Media |
| 4 | PostgreSQL | Sin `pg_stat_statements`. Impide análisis de consultas lentas | Media |
| 5 | PostgreSQL | 67% disco usado (27 GB). Revisar datos huérfanos y vacuum | Media |
| 6 | GeoNetwork | Sin configurar. No expone catálogo INSPIRE | Crítica |
| 7 | GeoNetwork | `elasticsearch` en servidor separado (Indices). Evaluar consolidación | Baja |

**Optimizaciones recomendadas (postgresql.conf):**
```ini
shared_buffers           = 4GB
work_mem                 = 64MB
maintenance_work_mem     = 1GB
effective_cache_size     = 12GB
random_page_cost         = 1.1      # SSD
effective_io_concurrency = 200      # SSD
wal_buffers              = 64MB
max_wal_size             = 4GB
checkpoint_completion_target = 0.9
shared_preload_libraries = 'pg_stat_statements,pg_cron'
log_min_duration_statement = 1000   # log queries > 1s
```

### Servidor GeoServer (Ubuntu 22.04)

**Estado actual:**
- GeoServer 2.22.2 con módulos GeoWebCache, Vector Tiles, INSPIRE
- Solo 17% del disco usado — margen suficiente para cachés WMTS (~20 GB)
- Tomcat 9.0.50 detrás de Apache (AJP)

**Hallazgos:**
| # | Área | Hallazgo | Severidad |
|---|------|----------|-----------|
| 1 | GeoServer | Versión 2.22.2 (jun. 2023). Actualizar a 2.25.2 | Alta |
| 2 | JVM | Sin opciones G1GC ni límite de heap definido | Alta |
| 3 | GeoServer | Sin WMTS habilitado para capas de alta demanda | Alta |
| 4 | GeoServer | Sin perfil INSPIRE en WMS/WFS | Media |
| 5 | Seguridad | Credenciales por defecto en algunos entornos | Crítica |
| 6 | Logs | Sin acceso estructurado a logs de peticiones | Media |

**Optimizaciones JVM recomendadas:**
```bash
export CATALINA_OPTS="-server -Xms2g -Xmx4g -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8"
```

**Capas candidatas a WMTS (por volumen de peticiones estimado):**
| Capa | Zoom recomendado | Tamaño caché estimado |
|------|------------------|-----------------------|
| Cartografía base | 0–18 | 8–10 GB |
| Ortofotos históricas | 0–15 | 4–6 GB/vuelo |
| Callejero | 8–18 | 1–2 GB |
| Plan General | 8–16 | 300–500 MB |
| Zonas verdes | 8–16 | 150–200 MB |

### Servidor Índices (Ubuntu 20.04)

**Estado actual:**
- Elasticsearch 7.6.2 + Kibana — ambos EOL desde feb. 2022
- En proceso de estudio su eliminación para integrar en ELK corporativo

**Recomendación:** Migrar a Elasticsearch 8.x como componente de la IDEG para auditoría de accesos OGC. Aprovechar el volumen disponible (57% libre de 40 GB).

### Servidor Mapstore (Ubuntu 22.04)

**Estado actual:**
- Apache 2.4.52 como frontal de `ideg.gijon.es`
- QGIS Server instalado (versión no especificada)
- 84% del disco libre (100 GB disponibles)

**Hallazgos:**
| # | Área | Hallazgo | Severidad |
|---|------|----------|-----------|
| 1 | QGIS Server | Sin configuración de proyectos publicados | Alta |
| 2 | Apache | Sin configuración de acceso diferenciado por nivel | Alta |
| 3 | Visor | MapStore sin integrar con los servicios OGC de la IDEG | Media |
| 4 | HTTPS | Verificar certificado SSL y renovación automática | Alta |

## Plan de actuación priorizado

**Fase 1 (semanas 1-4): Infraestructura de base**
1. Actualizar PostgreSQL 12 → 16 (con PostGIS 3.4)
2. Aplicar optimizaciones `postgresql.conf`
3. Actualizar GeoServer 2.22.2 → 2.25.2
4. Configurar JVM GeoServer con G1GC
5. Cambiar credenciales por defecto en todos los servicios

**Fase 2 (semanas 5-8): Servicios OGC y catálogo**
1. Publicar workspace `ideg` en GeoServer con todas las capas
2. Habilitar WMTS con GeoWebCache para capas de alta demanda
3. Configurar GeoNetwork con perfiles INSPIRE y grupos de acceso
4. Configurar QGIS Server con proyectos y virtual host Apache

**Fase 3 (semanas 9-12): Visor, monitorización y auditoría**
1. Desplegar MapStore como visor IDEG en Sede Electrónica
2. Desplegar Prometheus + Grafana para monitorización
3. Desplegar Elasticsearch 8.x + Kibana para auditoría
4. Configurar alertas y procedimientos operativos
5. Formación al personal técnico municipal (20h)
