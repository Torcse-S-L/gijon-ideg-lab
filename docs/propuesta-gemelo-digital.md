# Propuesta de Gemelo Digital del Municipio de Gijón/Xixón

## Resumen ejecutivo

El gemelo digital (Digital Twin) del municipio de Gijón propone una representación virtual 3D del territorio que integra datos geoespaciales, sensórica IoT y simulación en tiempo real, permitiendo a los departamentos municipales analizar, planificar y tomar decisiones basadas en datos con un impacto directo en la calidad de vida de los ciudadanos.

Esta propuesta es complementaria a la IDEG y la enriquece con una dimensión temporal y tridimensional.

---

## Alcance propuesto

### Capa geoespacial base (3D)

- Modelo de Superficie Digital (MDS) a resolución 0.5 m/píx sobre la totalidad del municipio (182 km²)
- Modelo de Elevación Digital (MED) derivado
- Nube de puntos LiDAR (clasificación automática: suelo, vegetación, edificios, agua)
- Fotogrametría de fachadas en el casco urbano consolidado
- Integración con Catastro 3D (LOD2)

### Capas temáticas dinámicas

| Dominio | Datos | Frecuencia actualización |
|---------|-------|--------------------------|
| Tráfico | Contadores de tráfico, aparcamientos | Tiempo real |
| Calidad del aire | Estaciones de monitorización | Cada 15 min |
| Iluminación pública | Inventario, consumo, averías | Diaria |
| Redes de servicios | Agua, saneamiento, gas (BIM/CityGML) | Mensual |
| Urbanismo | Licencias, obras, expedientes | Diaria |
| Vegetación | Índice NDVI, riesgo incendio | Semanal |
| Ruido | Mapas de ruido actualizados (Directiva 2002/49/CE) | Anual |

### Casos de uso prioritarios

1. **Planificación urbana** — simulación del impacto de nuevas construcciones (sombras, visibilidad, densidad)
2. **Gestión de emergencias** — simulación de inundaciones (análisis de cuencas + lluvia en tiempo real)
3. **Movilidad sostenible** — optimización de rutas y simulación de nuevos carriles bici/peatonales
4. **Eficiencia energética** — análisis de potencial solar en cubiertas
5. **Mantenimiento predictivo** — deterioro de infraestructuras (pavimento, arbolado, redes)

---

## Arquitectura técnica propuesta

```
┌──────────────────────────────────────────────────────────────────┐
│                    Gemelo Digital Gijón                          │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  LiDAR /    │  │ Sensórica   │  │  Fuentes administrativas│  │
│  │ Fotogramet. │  │ IoT (MQTT)  │  │  Catastro, ERP TAO2     │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
│         └────────────────┴──────────────────────┘               │
│                                │                                 │
│                                ▼                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │             Motor de datos espaciales 3D                 │   │
│  │   PostgreSQL/PostGIS + pg_pointcloud + CityGML           │   │
│  │   3DCityDB + CESIUM ION / CesiumJS                       │   │
│  └──────────────────────────┬───────────────────────────────┘   │
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  API REST    │  │  OGC API     │  │  Dashboard ejecutivo │  │
│  │  (FastAPI)   │  │  Features 3D │  │  (CesiumJS / Deck.gl)│  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                              │                                   │
│                              ▼                                   │
│                   IDEG Gijón (GeoServer / GeoNetwork)            │
└──────────────────────────────────────────────────────────────────┘
```

**Integración con la IDEG:**  
El gemelo digital consume y enriquece los servicios OGC existentes de la IDEG. Las capas 3D se publican como WMS/WFS estándar y como OGC API Features, manteniendo la interoperabilidad con herramientas GIS de escritorio (QGIS, ArcGIS).

---

## Valoración económica

### Inversión inicial (año 1)

| Concepto | Coste estimado (€ IVA excl.) |
|----------|------------------------------|
| Vuelo LiDAR municipal (182 km²) | 55.000 – 75.000 |
| Fotogrametría casco urbano (15 km²) | 25.000 – 35.000 |
| Integración 3DCityDB + CesiumJS | 40.000 – 55.000 |
| Desarrollo API REST y dashboard | 35.000 – 50.000 |
| Integración IoT (10 sensores piloto) | 20.000 – 30.000 |
| Formación y documentación | 8.000 – 12.000 |
| **Total año 1** | **183.000 – 257.000** |

### Coste de mantenimiento anual (años 2–10)

| Concepto | Coste anual estimado (€) |
|----------|--------------------------|
| Actualización LiDAR (vuelo bienal) | 15.000 – 20.000 |
| Mantenimiento software y plataforma | 18.000 – 25.000 |
| Actualización fuentes de datos | 8.000 – 12.000 |
| Soporte y evolución funcional | 20.000 – 30.000 |
| **Total anual** | **61.000 – 87.000** |

### Coste total a 10 años (VPN al 3%)

| Escenario | Inversión total 10 años |
|-----------|------------------------|
| Mínimo | ~724.000 € |
| Máximo | ~1.040.000 € |
| **Escenario base** | **~880.000 €** |

---

## Beneficios esperados

- Reducción del 30–40% en tiempo de resolución de expedientes urbanísticos complejos
- Ahorro estimado del 15% en mantenimiento de infraestructuras (predicción de averías)
- Mejora de la toma de decisiones en emergencias y planificación urbana
- Cumplimiento anticipado de la futura regulación europea sobre gemelos digitales urbanos (iniciativa Destination Earth)
- Posicionamiento de Gijón como ciudad referente en transformación digital municipal

---

## Hoja de ruta sugerida

| Fase | Plazo | Hito |
|------|-------|------|
| 1 — Base 3D | Meses 1–6 | LiDAR + fotogrametría + 3DCityDB |
| 2 — Integración | Meses 7–12 | API, dashboard, OGC API Features |
| 3 — IoT y tiempo real | Año 2 | Sensórica tráfico y calidad aire |
| 4 — Casos de uso | Años 2–3 | Planificación urbana, inundaciones, energía |
| 5 — Consolidación | Años 4–5 | Extensión a otros dominios + formación |
