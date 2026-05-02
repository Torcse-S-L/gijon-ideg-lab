# Arquitectura IDEG Gijón/Xixón

## Visión general

La Infraestructura de Datos Espaciales del Ayuntamiento de Gijón (IDEG) implementa los requisitos de la Directiva INSPIRE (2007/2/CE) y la LISIGE (Ley 14/2010) sobre un stack de software libre que aprovecha la infraestructura tecnológica existente.

## Componentes

### Base de datos: PostgreSQL 16 / PostGIS 3.4

Componente central de la IDEG. Almacena todos los datos georreferenciados en ETRS89 UTM Zone 30N (EPSG:25830).

**Esquemas:**
| Esquema | Propósito |
|---------|-----------|
| `gis.*` | Datos georreferenciados municipales (cartografía, urbanismo, patrimonio, movilidad) |
| `inspire.*` | Metadatos conformes a ISO 19115/19139 y INSPIRE |
| `compat.*` | Vistas de compatibilidad para herramientas GIS legadas (SITMAP, plugin EIEL QGIS) |
| `audit.*` | Auditoría de accesos a servicios OGC y cambios en datos |
| `catalog.*` | Catálogo de recursos con niveles de acceso |

**Extensiones activadas:** `postgis`, `postgis_topology`, `postgis_raster`, `pg_trgm`, `unaccent`, `pg_cron`, `pgrouting`, `uuid-ossp`

### GeoServer 2.25.2

Servidor OGC que publica los datos de PostgreSQL/PostGIS como servicios estándar. Corre sobre Apache Tomcat 9.x detrás de Apache HTTP (proxy AJP).

**Servicios publicados:**
- WMS 1.1.1 / 1.3.0 — mapas raster bajo demanda
- WFS 1.0.0 / 2.0.0 — descarga de datos vectoriales
- WCS 1.1.1 / 2.0.0 — coberturas raster (ortofotos)
- WMTS 1.0.0 — teselas pre-cacheadas (GeoWebCache)
- Vector Tiles — teselas vectoriales para visores modernos

**Módulos adicionales:** INSPIRE Extension, GeoWebCache, CSS Styling, Vector Tiles

**Workspace:** `ideg` con datastore PostGIS apuntando a la BD `GISDB`

### GeoNetwork 4.2.8

Catálogo de metadatos INSPIRE. Indexa y expone los metadatos de todas las capas de la IDEG conformes a ISO 19115 / ISO 19119.

**Servicios:** CSW 2.0.2, OAI-PMH, OpenSearch, API REST

**Niveles de acceso configurados:**
- `publico` — accesible sin autenticación desde internet (Sede Electrónica)
- `publico_protegido` — requiere credenciales de ciudadano
- `interno_publico` — intranet municipal sin credenciales
- `interno_privado` — intranet municipal con autenticación

**Harvesting:** extracción automática de metadatos desde GeoServer (diaria a las 02:00)

### QGIS Server 3.34

Servidor WMS/WFS complementario para capas que requieren simbología avanzada o procesamiento QGIS. Virtual host Apache independiente.

### MapStore (Visor IDEG)

Visor cartográfico web accesible desde la Sede Electrónica. Integra capas WMS/WMTS públicas de GeoServer, ortofotos históricas y permite búsqueda por dirección (callejero).

### Stack de Monitorización

- **Prometheus 2.53** — recopilación de métricas de todos los componentes
- **Grafana 11.1** — dashboards de disponibilidad, rendimiento y auditoría
- **Elasticsearch 8.14 + Kibana** — gestión centralizada de logs de acceso OGC

## Flujo de datos

```
Fuentes externas (IGN, INE, Catastro)
         │
         ▼
   PostgreSQL/PostGIS (GISDB)
    ├── gis.*     (datos cartográficos)
    ├── inspire.* (metadatos)
    ├── audit.*   (log de accesos)
    └── catalog.* (catálogo recursos)
         │
    ┌────┴─────────────────────┐
    ▼                          ▼
GeoServer                  GeoNetwork
(WMS/WFS/WMTS)             (CSW/INSPIRE)
    │                          │
    └─────────┬────────────────┘
              ▼
        Apache / MapStore
        (Visor IDEG — Sede Electrónica)
              │
              ▼
         Ciudadanos / Departamentos municipales
```

## Seguridad

- Acceso VPN para personal externo (adjudicatario)
- Autenticación por niveles en GeoNetwork y GeoServer
- Logs de acceso en PostgreSQL (`audit.*`) y Elasticsearch
- Backup diario automático vía `pg_cron` + rotación a 7 días
- Actualizaciones planificadas en horario de baja carga

## Integración con la IDEE

Los recursos de nivel `publico` se sincronizan con la Infraestructura de Datos Espaciales de España (IDEE) mediante protocolo CSW-T y harvesting OGC desde el nodo central del IGN.
