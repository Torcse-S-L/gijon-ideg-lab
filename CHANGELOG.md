# Changelog

Todos los cambios notables de este proyecto se documentan en este fichero.
Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

## [0.3.0] — 2026-05-08

### Añadido
- CI/CD con GitHub Actions: lint YAML, validación SQL, tests e2e.
- Dashboard de auditoría de accesos en Grafana (04-audit.json).
- Propuesta de gemelo digital con valoración económica a 10 años.
- Tests de humo para servicios OGC (WMS, WFS, WMTS, CSW).

### Corregido
- Configuración AJP entre Apache y Tomcat en QGIS Server.
- Permisos de acceso en recursos internos privados de GeoNetwork.

## [0.2.0] — 2026-04-15

### Añadido
- Stack de monitorización completo: Prometheus + Grafana + alertas.
- Integración Elasticsearch + Kibana para auditoría de accesos GIS.
- Scripts de backup y restore de PostgreSQL y GeoServer.
- Configuración QGIS Server con virtual host Apache.
- Visor cartográfico MapStore con capas base e históricas.

### Cambiado
- GeoServer actualizado a 2.25.2 con módulos INSPIRE y Vector Tiles.
- Optimización de parámetros JVM para GeoServer (4 GB máximo).

## [0.1.0] — 2026-03-25

### Añadido
- Bootstrap inicial del proyecto con docker-compose y .gitignore.
- Esquemas PostGIS: extensiones, INSPIRE, datos de ejemplo Gijón.
- Migraciones SQL: metadatos INSPIRE, vistas de compatibilidad, auditoría.
- Configuración y auto-setup GeoServer: capas WMS/WFS, cachés WMTS.
- Configuración GeoNetwork: perfiles INSPIRE, roles y políticas de acceso.
- Documentación técnica: arquitectura, análisis de infraestructura, INSPIRE.
