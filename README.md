# Gijón IDEG Lab

[![CI — Validación](https://github.com/Torcse-S-L/gijon-ideg-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/Torcse-S-L/gijon-ideg-lab/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

Laboratorio de referencia para el desarrollo de la **Infraestructura de Datos Espaciales del Ayuntamiento de Gijón/Xixón (IDEG)**. Implementa un entorno completo y reproducible que demuestra el análisis, diseño, configuración y validación de todos los componentes técnicos requeridos por el pliego de prescripciones técnicas del contrato (Exp. 15296Q/2026): PostgreSQL/PostGIS, GeoServer, GeoNetwork INSPIRE, QGIS Server, WMTS, monitorización y auditoría.

## Objetivo

Demostrar un proceso completo de despliegue y operación de la IDEG del Ayuntamiento de Gijón aplicable al entorno de producción, incluyendo:

- Análisis y optimización de la infraestructura GIS existente (GeoServer 2.22.2, GeoNetwork 4.0.5, PostgreSQL 12).
- Configuración INSPIRE-compliant del catálogo GeoNetwork con perfiles de usuario y control de acceso por niveles (público, protegido, interno).
- Publicación de servicios OGC (WMS, WFS, WCS, WMTS) con cachés y Vector Tiles.
- Visor cartográfico IDEG integrado en la Sede Electrónica del Ayuntamiento.
- Stack de monitorización y auditoría con Prometheus, Grafana y Elasticsearch.
- Scripts de backup, restore y actualización de componentes.
- Propuesta de gemelo digital del municipio y valoración económica a 10 años.

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Docker Compose (Lab)                          │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │              PostgreSQL 16 / PostGIS 3.4  :5432                  │  │
│  │  GISDB: gis.* · inspire.* · compat.* · audit.* · catalog.*      │  │
│  └──────────────────────┬───────────────────────────────────────────┘  │
│                         │                                              │
│          ┌──────────────┼──────────────┐                              │
│          ▼              ▼              ▼                              │
│  ┌──────────────┐ ┌───────────┐ ┌──────────────┐                    │
│  │  GeoServer   │ │GeoNetwork │ │  QGIS Server │                    │
│  │  :8080       │ │  :8081    │ │   :8082      │                    │
│  │  WMS/WFS     │ │  INSPIRE  │ │  WMS/WFS     │                    │
│  │  WMTS/WCS    │ │  catalog  │ │  avanzado    │                    │
│  └──────┬───────┘ └─────┬─────┘ └──────┬───────┘                    │
│         │               │              │                              │
│         └───────────────┴──────────────┘                              │
│                          │                                             │
│                          ▼                                             │
│  ┌───────────────────────────────────────────────────────────────┐    │
│  │            Apache / MapStore  :80  (Visor IDEG)               │    │
│  │              https://ideg.gijon.es (producción)               │    │
│  └───────────────────────────────────────────────────────────────┘    │
│                                                                        │
│  ┌────────────────────┐   ┌──────────────────────────────────────┐   │
│  │ Prometheus  :9090  │   │         Grafana  :3000               │   │
│  │ (métricas GIS)     │   │  01 Vista ejecutiva IDEG             │   │
│  └──────────┬─────────┘   │  02 Rendimiento GeoServer            │   │
│             │              │  03 Auditoría accesos                │   │
│             └──────────────►  04 Estado infraestructura           │   │
│                            └──────────────────────────────────────┘   │
│                                                                        │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │  Elasticsearch :9200 + Kibana :5601  (auditoría y logs)        │   │
│  └────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Inicio Rápido

### Requisitos Previos

- [Docker Engine](https://docs.docker.com/engine/install/) 24+
- [Docker Compose](https://docs.docker.com/compose/install/) v2+
- 8 GB de RAM disponible (16 GB recomendado para stack completo)
- 20 GB de espacio en disco
- Puertos libres: 80, 3000, 5432, 8080, 8081, 8082, 9090, 9200, 5601

### Despliegue

```bash
# 1. Clonar el repositorio
git clone https://github.com/Torcse-S-L/gijon-ideg-lab.git
cd gijon-ideg-lab

# 2. Copiar y ajustar variables de entorno
cp .env.example .env
# Editar .env con contraseñas, credenciales SMTP, etc.

# 3. Inicializar el entorno
bash scripts/bootstrap_lab.sh

# 4. Esperar ~3 minutos a que GeoServer y GeoNetwork arranquen

# 5. Acceder a los servicios
# Visor IDEG:       http://localhost/ideg
# GeoServer:        http://localhost:8080/geoserver  (admin / geoserver)
# GeoNetwork:       http://localhost:8081/geonetwork (admin / admin)
# Grafana:          http://localhost:3000             (admin / admin)
# Kibana:           http://localhost:5601
```

En Windows PowerShell:

```powershell
Copy-Item .env.example .env
.\scripts\bootstrap_lab.ps1
```

### Verificación

```bash
# Ejecutar suite de tests e2e
bash tests/test_ideg_e2e.sh

# Verificar servicios OGC individualmente
bash tests/test_ogc_services.sh
```

## Servicios OGC Publicados

| Servicio | URL | Descripción |
|----------|-----|-------------|
| WMS | `/geoserver/ideg/wms` | Mapas de cartografía básica y temática |
| WFS | `/geoserver/ideg/wfs` | Descarga de datos vectoriales |
| WCS | `/geoserver/ideg/wcs` | Cobertura raster (ortofotos) |
| WMTS | `/geoserver/gwc/service/wmts` | Teselas en caché |
| CSW | `/geonetwork/srv/eng/csw` | Catálogo INSPIRE |

## Niveles de Acceso (GeoNetwork)

| Nivel | Descripción | Visibilidad |
|-------|-------------|-------------|
| Público | Datos de libre acceso | Internet (Sede Electrónica) |
| Público protegido | Acceso con credenciales ciudadanas | Sede Electrónica (autenticado) |
| Interno público | Sin credenciales, solo intranet | Red municipal |
| Interno privado | Credenciales municipales requeridas | Red municipal (autenticado) |

## Estructura del Proyecto

```
├── .github/workflows/ci.yml           # CI: lint YAML, validar SQL, tests
├── docker-compose.yml                  # Orquestación ~10 servicios
├── .env.example                        # Variables de entorno (plantilla)
├── postgres/
│   ├── init/
│   │   ├── 01-extensions.sql           # PostGIS, pg_trgm, unaccent
│   │   ├── 02-inspire-schema.sql       # Esquemas INSPIRE/IDEG
│   │   └── 03-sample-data-gijon.sql    # Datos de ejemplo Gijón
│   └── migrations/
│       ├── 001_inspire_metadata.sql    # Tablas de metadatos INSPIRE
│       ├── 002_compat_views.sql        # Vistas de compatibilidad GIS
│       └── 003_audit_tables.sql        # Tablas de auditoría de accesos
├── geoserver/
│   ├── setup/
│   │   ├── configure_layers.sh         # Auto-configuración capas WMS/WFS
│   │   └── configure_wmts_cache.sh     # Configuración cachés WMTS
│   └── config/
│       └── jvm_options.txt             # Opciones JVM para optimización
├── geonetwork/
│   ├── setup/
│   │   └── configure_geonetwork.sh     # Perfiles, usuarios, políticas
│   └── config/
│       ├── inspire-profile.xml         # Perfil de metadatos INSPIRE
│       └── users.xml                   # Definición de roles y permisos
├── qgis-server/
│   └── config/
│       ├── qgis-server.conf            # Configuración QGIS Server
│       └── apache-qgis.conf            # Virtual host Apache
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml              # Config + scrape targets GIS
│   │   └── alerts/gis-alerts.yml       # Reglas de alertas GIS
│   └── grafana/
│       ├── provisioning/               # Auto-provisioning datasources
│       └── dashboards/                 # 4 dashboards JSON
├── scripts/
│   ├── bootstrap_lab.sh / .ps1         # Inicialización completa
│   ├── run_migrations.sh               # Aplicación de migraciones SQL
│   └── backup_restore.sh               # Backup/restore PostgreSQL + GeoServer
├── tests/
│   ├── test_ideg_e2e.sh                # Tests e2e del stack completo
│   └── test_ogc_services.sh            # Tests de servicios OGC
└── docs/
    ├── arquitectura.md                  # Arquitectura detallada IDEG
    ├── analisis-infraestructura.md      # Análisis infraestructura existente
    ├── inspire-config.md                # Guía configuración INSPIRE
    ├── procedimiento-operativo.md       # Mantenimiento, backup, seguridad
    └── propuesta-gemelo-digital.md      # Propuesta gemelo digital + costes
```

## Documentación

- [Arquitectura](docs/arquitectura.md) — Componentes, flujos de datos y decisiones de diseño
- [Análisis de infraestructura](docs/analisis-infraestructura.md) — Diagnóstico del estado actual y optimizaciones
- [Configuración INSPIRE](docs/inspire-config.md) — Catálogo GeoNetwork y metadatos conformes INSPIRE
- [Procedimiento operativo](docs/procedimiento-operativo.md) — Backup, restore, actualizaciones y seguridad
- [Propuesta gemelo digital](docs/propuesta-gemelo-digital.md) — Arquitectura, alcance y valoración económica

## Puertos

| Servicio | Puerto |
|----------|--------|
| Apache / Visor IDEG | 80 |
| GeoServer | 8080 |
| GeoNetwork | 8081 |
| QGIS Server | 8082 |
| Grafana | 3000 |
| PostgreSQL/PostGIS | 5432 |
| Prometheus | 9090 |
| Elasticsearch | 9200 |
| Kibana | 5601 |

## Tecnologías

| Componente | Versión | Función |
|------------|---------|---------|
| PostgreSQL | 16 | Motor de base de datos relacional |
| PostGIS | 3.4 | Extensión espacial |
| GeoServer | 2.25.2 | Servidor WMS/WFS/WCS/WMTS |
| GeoNetwork | 4.2.8 | Catálogo de metadatos INSPIRE |
| QGIS Server | 3.34 | Servidor WMS/WFS avanzado |
| MapStore | 2024.01 | Visor cartográfico web |
| Prometheus | 2.53.0 | Recopilación de métricas |
| Grafana | 11.1.0 | Dashboards y alertas |
| Elasticsearch | 8.14.0 | Auditoría y búsqueda de logs |
| Docker Compose | v2+ | Orquestación del laboratorio |

## Proyectos relacionados (mismo equipo)

- [Torcse-S-L/EIEL-Data-Model-Modernization-Lab](https://github.com/Torcse-S-L/EIEL-Data-Model-Modernization-Lab) — modernización del modelo de datos EIEL.
- [Torcse-S-L/metrics-stack-playground](https://github.com/Torcse-S-L/metrics-stack-playground) — monitorización de infraestructura GIS.
- [Torcse-S-L/qgist-eiel-ine-integration](https://github.com/Torcse-S-L/qgist-eiel-ine-integration) — integración EIEL con fuentes INE.

## Licencia

Este proyecto está licenciado bajo [Apache License 2.0](LICENSE).

Desarrollado por [Torcse S.L.](https://github.com/Torcse-S-L)
