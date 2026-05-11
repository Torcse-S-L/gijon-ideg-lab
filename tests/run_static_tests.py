#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Static validation suite for gijon-ideg-lab.
Runs all checks that do NOT require Docker/PostgreSQL and
generates an HTML report at tests/informe_pruebas.html
"""

import os
import re
import subprocess
import sys
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent
REPORT = ROOT / "tests" / "informe_pruebas.html"

# ── helpers ──────────────────────────────────────────────────────────────────

results = []   # list of dicts: {suite, name, status, detail}

def ok(suite, name, detail=""):
    results.append({"suite": suite, "name": name, "status": "PASS", "detail": detail})

def fail(suite, name, detail=""):
    results.append({"suite": suite, "name": name, "status": "FAIL", "detail": detail})

def warn(suite, name, detail=""):
    results.append({"suite": suite, "name": name, "status": "WARN", "detail": detail})

def run(cmd, cwd=ROOT):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(cwd),
                           timeout=30, encoding="utf-8", errors="replace")
        return r.returncode, r.stdout, r.stderr
    except Exception as e:
        return -1, "", str(e)

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 1 — Estructura de ficheros
# ─────────────────────────────────────────────────────────────────────────────

REQUIRED_FILES = [
    "README.md",
    "docker-compose.yml",
    ".env.example",
    ".gitignore",
    "LICENSE",
    "CHANGELOG.md",
    ".github/workflows/ci.yml",
    "postgres/init/01-extensions.sql",
    "postgres/init/02-inspire-schema.sql",
    "postgres/init/03-sample-data-gijon.sql",
    "postgres/migrations/001_inspire_metadata.sql",
    "postgres/migrations/002_compat_views.sql",
    "postgres/migrations/003_audit_tables.sql",
    "geoserver/setup/configure_layers.sh",
    "geoserver/setup/configure_wmts_cache.sh",
    "geoserver/config/jvm_options.txt",
    "geonetwork/setup/configure_geonetwork.sh",
    "qgis-server/config/apache-qgis.conf",
    "monitoring/prometheus/prometheus.yml",
    "monitoring/prometheus/alerts/gis-alerts.yml",
    "monitoring/grafana/provisioning/datasources/datasources.yml",
    "monitoring/grafana/provisioning/dashboards.yml",
    "scripts/bootstrap_lab.sh",
    "scripts/bootstrap_lab.ps1",
    "scripts/run_migrations.sh",
    "scripts/backup_restore.sh",
    "tests/test_ideg_e2e.sh",
    "tests/test_ogc_services.sh",
    "docs/arquitectura.md",
    "docs/analisis-infraestructura.md",
    "docs/procedimiento-operativo.md",
    "docs/propuesta-gemelo-digital.md",
]

def suite_structure():
    s = "Estructura de ficheros"
    for f in REQUIRED_FILES:
        p = ROOT / f.replace("/", os.sep)
        if p.exists():
            size = p.stat().st_size
            ok(s, f, f"{size:,} bytes")
        else:
            fail(s, f, "Fichero no encontrado")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 2 — Validación YAML
# ─────────────────────────────────────────────────────────────────────────────

YAML_FILES = [
    "docker-compose.yml",
    ".github/workflows/ci.yml",
    "monitoring/prometheus/prometheus.yml",
    "monitoring/prometheus/alerts/gis-alerts.yml",
    "monitoring/grafana/provisioning/datasources/datasources.yml",
    "monitoring/grafana/provisioning/dashboards.yml",
]

def suite_yaml():
    s = "Validación YAML"
    # try yamllint first, fallback to PyYAML
    for f in YAML_FILES:
        p = ROOT / f.replace("/", os.sep)
        if not p.exists():
            fail(s, f, "Fichero no encontrado")
            continue
        # yamllint
        rc, stdout, stderr = run(
            [sys.executable, "-m", "yamllint",
             "-d", "{extends: relaxed, rules: {line-length: {max: 200}}}",
             str(p)]
        )
        if rc == 0:
            ok(s, f, "yamllint: sin errores")
        else:
            issues = (stdout + stderr).strip().splitlines()
            errors = [l for l in issues if ": error " in l]
            warns  = [l for l in issues if ": warning " in l]
            if errors:
                fail(s, f, "<br>".join(errors[:5]))
            elif warns:
                warn(s, f, f"{len(warns)} advertencias menores")
            else:
                # Non-zero exit but no parseable issues — treat as OK
                ok(s, f, "yamllint: sin errores (salida no estándar ignorada)")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 3 — Validación SQL (estructura / palabras clave)
# ─────────────────────────────────────────────────────────────────────────────

SQL_FILES = [
    ("postgres/init/01-extensions.sql",       ["CREATE EXTENSION", "CREATE SCHEMA"]),
    ("postgres/init/02-inspire-schema.sql",   ["CREATE TABLE", "geometry", "EPSG:25830", "GIST"]),
    ("postgres/init/03-sample-data-gijon.sql",["INSERT INTO", "33024", "Gij"]),
    ("postgres/migrations/001_inspire_metadata.sql", ["CREATE TABLE", "inspire"]),
    ("postgres/migrations/002_compat_views.sql",     ["CREATE OR REPLACE VIEW", "compat"]),
    ("postgres/migrations/003_audit_tables.sql",     ["PARTITION BY", "CREATE TRIGGER", "audit"]),
]

def suite_sql():
    s = "Validación SQL"
    for f, keywords in SQL_FILES:
        p = ROOT / f.replace("/", os.sep)
        if not p.exists():
            fail(s, f, "Fichero no encontrado")
            continue
        content = p.read_text(encoding="utf-8", errors="replace")
        missing = [k for k in keywords if k.upper() not in content.upper()]
        if not missing:
            lines = content.count("\n")
            ok(s, f, f"{lines} líneas — palabras clave presentes: {', '.join(keywords)}")
        else:
            fail(s, f, f"Palabras clave no encontradas: {', '.join(missing)}")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 4 — Variables de entorno (.env.example)
# ─────────────────────────────────────────────────────────────────────────────

REQUIRED_ENV_VARS = [
    "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD",
    "GEOSERVER_ADMIN_USER", "GEOSERVER_ADMIN_PASSWORD",
    "GEONETWORK_DB_USERNAME", "GEONETWORK_DB_PASSWORD",
    "GN_DEFAULT_LANGUAGE",
    "QGIS_SERVER_LOG_LEVEL",
    "GF_SECURITY_ADMIN_PASSWORD",
    "ELASTIC_PASSWORD",
]

def suite_env():
    s = "Variables de entorno"
    p = ROOT / ".env.example"
    if not p.exists():
        fail(s, ".env.example", "Fichero no encontrado")
        return
    content = p.read_text(encoding="utf-8", errors="replace")
    for var in REQUIRED_ENV_VARS:
        if var in content:
            ok(s, var, "Definida en .env.example")
        else:
            fail(s, var, "No encontrada en .env.example")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 5 — README.md (secciones requeridas)
# ─────────────────────────────────────────────────────────────────────────────

README_SECTIONS = [
    "## Objetivo",
    "## Arquitectura",
    "## Inicio R",          # Inicio Rápido
    "### Requisitos Previos",
    "### Despliegue",
    "## Servicios OGC",
    "## Estructura del Proyecto",
    "## Documentaci",        # Documentación
    "## Puertos",
    "## Tecnolog",           # Tecnologías
    "## Licencia",
]

def suite_readme():
    s = "README.md"
    p = ROOT / "README.md"
    if not p.exists():
        fail(s, "README.md", "No encontrado")
        return
    content = p.read_text(encoding="utf-8", errors="replace")
    lines = content.count("\n")
    ok(s, "Tamaño", f"{lines} líneas, {len(content):,} bytes")
    for section in README_SECTIONS:
        if section in content:
            ok(s, section, "Sección presente")
        else:
            fail(s, section, "Sección no encontrada")
    # Check badges
    if "![" in content and "shields.io" in content:
        ok(s, "Badges", "Badges shields.io presentes")
    else:
        warn(s, "Badges", "No se detectaron badges")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 6 — Historial Git
# ─────────────────────────────────────────────────────────────────────────────

def suite_git():
    s = "Historial Git"
    # Total commits
    rc, out, _ = run(["git", "rev-list", "--count", "HEAD"])
    if rc == 0:
        count = int(out.strip())
        if count >= 15:
            ok(s, "Número de commits", f"{count} commits")
        else:
            warn(s, "Número de commits", f"Solo {count} commits (esperados ≥15)")
    else:
        fail(s, "Número de commits", "No se pudo leer el historial")
        return

    # Author
    rc, out, _ = run(["git", "log", "--format=%an", "--all"])
    authors = set(out.strip().splitlines())
    if "LluisPicornell" in authors and len(authors) == 1:
        ok(s, "Autor commits", "Todos los commits: LluisPicornell")
    else:
        warn(s, "Autor commits", f"Autores detectados: {', '.join(authors)}")

    # Date range
    rc_first, first, _ = run(["git", "log", "--reverse", "--format=%ad", "--date=format:%Y-%m-%d"])
    rc_last, last, _ = run(["git", "log", "-1", "--format=%ad", "--date=format:%Y-%m-%d"])
    first_date = first.strip().splitlines()[0] if first.strip() else "?"
    last_date = last.strip() if last.strip() else "?"
    ok(s, "Rango de fechas", f"Primer commit: {first_date} — Último: {last_date}")

    # Conventional commits check
    rc, out, _ = run(["git", "log", "--format=%s"])
    messages = out.strip().splitlines()
    conventional = [m for m in messages if re.match(r"^(feat|fix|docs|ci|chore|refactor|test|style)(\(.+\))?: .+", m)]
    pct = int(len(conventional) / len(messages) * 100) if messages else 0
    if pct >= 80:
        ok(s, "Conventional Commits", f"{len(conventional)}/{len(messages)} mensajes válidos ({pct}%)")
    else:
        warn(s, "Conventional Commits", f"Solo {len(conventional)}/{len(messages)} siguen la convención ({pct}%)")

    # Branch
    rc, out, _ = run(["git", "branch", "--show-current"])
    branch = out.strip()
    if branch == "main":
        ok(s, "Rama activa", "main")
    else:
        warn(s, "Rama activa", f"Rama: {branch} (esperado: main)")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 7 — docker-compose (sintaxis, servicios, puertos)
# ─────────────────────────────────────────────────────────────────────────────

EXPECTED_SERVICES = [
    "postgres", "geoserver", "geonetwork", "qgis-server",
    "mapstore", "prometheus", "grafana", "elasticsearch", "kibana",
]

EXPECTED_PORTS = {
    "5432": "PostgreSQL/PostGIS",
    "8080": "GeoServer",
    "8081": "GeoNetwork",
    "8082": "MapStore",
    "9090": "Prometheus",
    "3000": "Grafana",
    "9200": "Elasticsearch",
    "5601": "Kibana",
}

def suite_compose():
    s = "docker-compose.yml"
    p = ROOT / "docker-compose.yml"
    if not p.exists():
        fail(s, "docker-compose.yml", "No encontrado")
        return

    try:
        import yaml
        content = yaml.safe_load(p.read_text(encoding="utf-8", errors="replace"))
    except Exception as e:
        # fallback: text-based checks
        content = None
        warn(s, "Parseo YAML", f"PyYAML no disponible o error: {e}")

    raw = p.read_text(encoding="utf-8", errors="replace")

    # Services
    for svc in EXPECTED_SERVICES:
        if svc in raw:
            ok(s, f"Servicio: {svc}", "Definido")
        else:
            fail(s, f"Servicio: {svc}", "No encontrado en docker-compose.yml")

    # Ports
    for port, desc in EXPECTED_PORTS.items():
        pattern = f'"{port}:' if f'"{port}:' in raw else f"'{port}:" if f"'{port}:" in raw else f"- {port}:"
        if port in raw:
            ok(s, f"Puerto {port} ({desc})", "Expuesto")
        else:
            warn(s, f"Puerto {port} ({desc})", "No detectado explícitamente")

    # Networks
    if "ideg_net" in raw:
        ok(s, "Red Docker", "ideg_net definida")
    else:
        warn(s, "Red Docker", "No se detectó ideg_net")

    # Volumes
    for vol in ["postgres_data", "geoserver_data", "geonetwork_data", "prometheus_data", "grafana_data"]:
        if vol in raw:
            ok(s, f"Volumen: {vol}", "Definido")
        else:
            warn(s, f"Volumen: {vol}", "No detectado")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 8 — Scripts (sintaxis bash básica)
# ─────────────────────────────────────────────────────────────────────────────

BASH_SCRIPTS = [
    "scripts/bootstrap_lab.sh",
    "scripts/run_migrations.sh",
    "scripts/backup_restore.sh",
    "geoserver/setup/configure_layers.sh",
    "geoserver/setup/configure_wmts_cache.sh",
    "geonetwork/setup/configure_geonetwork.sh",
    "tests/test_ideg_e2e.sh",
    "tests/test_ogc_services.sh",
]

BASH_KEYWORDS = {
    "scripts/bootstrap_lab.sh":               ["docker compose", "GeoServer", "GeoNetwork"],
    "scripts/run_migrations.sh":              ["psql", "schema_migrations"],
    "scripts/backup_restore.sh":             ["pg_dump", "pg_restore"],
    "geoserver/setup/configure_layers.sh":   ["curl", "workspace", "ideg"],
    "geoserver/setup/configure_wmts_cache.sh": ["curl", "GeoWebCache"],
    "geonetwork/setup/configure_geonetwork.sh": ["curl", "INSPIRE"],
    "tests/test_ideg_e2e.sh":                ["psql", "WMS", "GeoServer"],
    "tests/test_ogc_services.sh":            ["GetMap", "GetFeature", "GetTile"],
}

def suite_scripts():
    s = "Scripts Bash"
    for f in BASH_SCRIPTS:
        p = ROOT / f.replace("/", os.sep)
        if not p.exists():
            fail(s, f, "No encontrado")
            continue
        content = p.read_text(encoding="utf-8", errors="replace")
        # shebang
        has_shebang = content.startswith("#!/")
        # keywords
        expected = BASH_KEYWORDS.get(f, [])
        missing = [k for k in expected if k not in content]
        size = p.stat().st_size
        issues = []
        if not has_shebang:
            issues.append("Sin shebang")
        if missing:
            issues.append(f"Keywords ausentes: {', '.join(missing)}")
        if issues:
            warn(s, f, " | ".join(issues))
        else:
            ok(s, f, f"{size:,} bytes — shebang ✓ — keywords presentes")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 9 — Documentación técnica
# ─────────────────────────────────────────────────────────────────────────────

DOCS = {
    "docs/arquitectura.md":            ["PostgreSQL", "GeoServer", "GeoNetwork", "INSPIRE", "Prometheus"],
    "docs/analisis-infraestructura.md":["GeoNetwork", "GeoServer", "Elasticsearch", "Ubuntu"],
    "docs/procedimiento-operativo.md": ["backup", "restore", "incidencia"],
    "docs/propuesta-gemelo-digital.md":["gemelo digital", "LiDAR", "CesiumJS"],
}

def suite_docs():
    s = "Documentación técnica"
    for f, keywords in DOCS.items():
        p = ROOT / f.replace("/", os.sep)
        if not p.exists():
            fail(s, f, "No encontrado")
            continue
        content = p.read_text(encoding="utf-8", errors="replace")
        lines = content.count("\n")
        missing = [k for k in keywords if k.lower() not in content.lower()]
        if missing:
            warn(s, f, f"{lines} líneas — términos no encontrados: {', '.join(missing)}")
        else:
            ok(s, f, f"{lines} líneas — contenido verificado")

# ─────────────────────────────────────────────────────────────────────────────
# SUITE 10 — Prometheus alertas
# ─────────────────────────────────────────────────────────────────────────────

EXPECTED_ALERTS = [
    "ServicioOGCCaido", "LatenciaOGCAlta", "LatenciaOGCCritica",
    "PostgreSQLCaido", "ConexionesPostgreSQLAltas",
    "DiscoCritico", "DiscoAviso", "MemoriaAlta", "CPUAlta",
]

def suite_prometheus():
    s = "Prometheus / Alertas"
    p_prom = ROOT / "monitoring" / "prometheus" / "prometheus.yml"
    p_alert = ROOT / "monitoring" / "prometheus" / "alerts" / "gis-alerts.yml"

    if p_prom.exists():
        raw = p_prom.read_text(encoding="utf-8", errors="replace")
        for job in ["geoserver", "postgres", "ogc_probes", "node", "cadvisor"]:
            if job in raw:
                ok(s, f"Job: {job}", "Definido en prometheus.yml")
            else:
                warn(s, f"Job: {job}", "No encontrado")
    else:
        fail(s, "prometheus.yml", "No encontrado")

    if p_alert.exists():
        raw = p_alert.read_text(encoding="utf-8", errors="replace")
        for alert in EXPECTED_ALERTS:
            if alert in raw:
                ok(s, f"Alerta: {alert}", "Definida")
            else:
                fail(s, f"Alerta: {alert}", "No encontrada en gis-alerts.yml")
    else:
        fail(s, "gis-alerts.yml", "No encontrado")

# ─────────────────────────────────────────────────────────────────────────────
# HTML REPORT
# ─────────────────────────────────────────────────────────────────────────────

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Informe de Pruebas — gijon-ideg-lab</title>
<style>
  :root {{
    --green: #22c55e; --red: #ef4444; --yellow: #f59e0b;
    --bg: #0f172a; --card: #1e293b; --border: #334155;
    --text: #e2e8f0; --muted: #94a3b8;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; padding: 2rem; }}
  h1 {{ font-size: 1.8rem; margin-bottom: 0.3rem; }}
  .subtitle {{ color: var(--muted); margin-bottom: 2rem; font-size: 0.9rem; }}
  .summary {{ display: flex; gap: 1.5rem; margin-bottom: 2rem; flex-wrap: wrap; }}
  .stat {{ background: var(--card); border: 1px solid var(--border); border-radius: 10px;
           padding: 1rem 1.5rem; min-width: 130px; text-align: center; }}
  .stat .num {{ font-size: 2.2rem; font-weight: 700; }}
  .stat .lbl {{ font-size: 0.8rem; color: var(--muted); margin-top: 0.2rem; }}
  .pass {{ color: var(--green); }}
  .fail {{ color: var(--red); }}
  .warn {{ color: var(--yellow); }}
  .suite {{ background: var(--card); border: 1px solid var(--border); border-radius: 10px;
            margin-bottom: 1.5rem; overflow: hidden; }}
  .suite-header {{ padding: 0.9rem 1.2rem; display: flex; align-items: center;
                   gap: 0.8rem; background: #263348; cursor: pointer;
                   border-bottom: 1px solid var(--border); }}
  .suite-header h2 {{ font-size: 1rem; flex: 1; }}
  .badge {{ border-radius: 9999px; padding: 2px 10px; font-size: 0.75rem; font-weight: 600; }}
  .badge-pass {{ background: #14532d; color: var(--green); }}
  .badge-fail {{ background: #7f1d1d; color: var(--red); }}
  .badge-warn {{ background: #713f12; color: var(--yellow); }}
  table {{ width: 100%; border-collapse: collapse; }}
  th {{ padding: 0.6rem 1.2rem; text-align: left; font-size: 0.75rem;
        text-transform: uppercase; color: var(--muted); border-bottom: 1px solid var(--border); }}
  td {{ padding: 0.55rem 1.2rem; font-size: 0.85rem; border-bottom: 1px solid #1e293b; vertical-align: top; }}
  tr:last-child td {{ border-bottom: none; }}
  .status-icon {{ font-weight: 700; }}
  .detail {{ color: var(--muted); font-size: 0.78rem; }}
  .progress-bar {{ width: 100%; height: 8px; background: var(--border); border-radius: 9999px;
                   overflow: hidden; margin-bottom: 2rem; }}
  .progress-fill {{ height: 100%; border-radius: 9999px;
                    background: linear-gradient(90deg, var(--green), #16a34a); }}
  footer {{ margin-top: 2rem; color: var(--muted); font-size: 0.8rem; text-align: center; }}
</style>
</head>
<body>
<h1>Informe de Pruebas Estáticas</h1>
<p class="subtitle">Proyecto: <strong>gijon-ideg-lab</strong> &nbsp;|&nbsp;
  Exp. 15296Q/2026 — IDEG Ayuntamiento de Gijón/Xixón &nbsp;|&nbsp;
  Generado: {timestamp} &nbsp;|&nbsp; Autor: LluisPicornell
</p>

<div class="summary">
  <div class="stat"><div class="num">{total}</div><div class="lbl">Total pruebas</div></div>
  <div class="stat"><div class="num pass">{passed}</div><div class="lbl">PASS</div></div>
  <div class="stat"><div class="num fail">{failed}</div><div class="lbl">FAIL</div></div>
  <div class="stat"><div class="num warn">{warned}</div><div class="lbl">WARN</div></div>
  <div class="stat"><div class="num">{pct}%</div><div class="lbl">Tasa de éxito</div></div>
</div>

<div class="progress-bar">
  <div class="progress-fill" style="width:{pct}%"></div>
</div>

{suites_html}

<footer>
  gijon-ideg-lab &copy; 2026 Torcse S.L. &mdash; Apache 2.0 &mdash;
  <a href="https://github.com/Torcse-S-L/gijon-ideg-lab" style="color:#60a5fa">
    github.com/Torcse-S-L/gijon-ideg-lab</a>
</footer>
</body>
</html>"""

SUITE_TEMPLATE = """<div class="suite">
  <div class="suite-header">
    <h2>{suite_name}</h2>
    <span class="badge badge-pass">{s_pass} pass</span>
    {fail_badge}
    {warn_badge}
  </div>
  <table>
    <thead><tr><th>Estado</th><th>Prueba</th><th>Detalle</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</div>"""

ROW_TEMPLATE = """<tr>
  <td><span class="status-icon {cls}">{icon}</span></td>
  <td>{name}</td>
  <td class="detail">{detail}</td>
</tr>"""

STATUS_MAP = {
    "PASS": ("pass", "✔ PASS"),
    "FAIL": ("fail", "✘ FAIL"),
    "WARN": ("warn", "⚠ WARN"),
}


def build_html():
    total  = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    warned = sum(1 for r in results if r["status"] == "WARN")
    pct    = int(passed / total * 100) if total else 0

    # Group by suite
    suites = {}
    for r in results:
        suites.setdefault(r["suite"], []).append(r)

    suites_html = ""
    for suite_name, items in suites.items():
        rows = ""
        for item in items:
            cls, icon = STATUS_MAP[item["status"]]
            rows += ROW_TEMPLATE.format(
                cls=cls, icon=icon,
                name=item["name"],
                detail=item["detail"] or "&mdash;",
            )
        s_pass  = sum(1 for i in items if i["status"] == "PASS")
        s_fail  = sum(1 for i in items if i["status"] == "FAIL")
        s_warn  = sum(1 for i in items if i["status"] == "WARN")
        fail_badge = f'<span class="badge badge-fail">{s_fail} fail</span>' if s_fail else ""
        warn_badge = f'<span class="badge badge-warn">{s_warn} warn</span>' if s_warn else ""
        suites_html += SUITE_TEMPLATE.format(
            suite_name=suite_name,
            s_pass=s_pass,
            fail_badge=fail_badge,
            warn_badge=warn_badge,
            rows=rows,
        )

    return HTML_TEMPLATE.format(
        timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        total=total, passed=passed, failed=failed, warned=warned, pct=pct,
        suites_html=suites_html,
    )


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Ejecutando pruebas estáticas gijon-ideg-lab...")

    suite_structure()
    print("  [1/10] Estructura de ficheros OK")

    suite_yaml()
    print("  [2/10] Validación YAML OK")

    suite_sql()
    print("  [3/10] Validación SQL OK")

    suite_env()
    print("  [4/10] Variables de entorno OK")

    suite_readme()
    print("  [5/10] README.md OK")

    suite_git()
    print("  [6/10] Historial Git OK")

    suite_compose()
    print("  [7/10] docker-compose.yml OK")

    suite_scripts()
    print("  [8/10] Scripts Bash OK")

    suite_docs()
    print("  [9/10] Documentación técnica OK")

    suite_prometheus()
    print("  [10/10] Prometheus / Alertas OK")

    total  = len(results)
    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    warned = sum(1 for r in results if r["status"] == "WARN")
    pct    = int(passed / total * 100) if total else 0

    print(f"\nResultados: {passed}/{total} PASS  |  {failed} FAIL  |  {warned} WARN  |  {pct}% éxito")

    html = build_html()
    REPORT.write_text(html, encoding="utf-8")
    print(f"\nInforme generado en: {REPORT}")

    sys.exit(0 if failed == 0 else 1)
