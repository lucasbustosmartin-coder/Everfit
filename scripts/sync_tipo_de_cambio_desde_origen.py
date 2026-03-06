#!/usr/bin/env python3
"""
Sincroniza la tabla tipos_cambio_global del proyecto Sistema-Contable-Nuevo hacia la tabla
tipo_de_cambio del proyecto Everfit. Así Everfit tiene una copia local para mostrar montos en ARS y USD.

Origen: proyecto Sistema-Contable-Nuevo, tabla tipos_cambio_global (fecha, usd_mep, usd_ccl, usd_oficial).
Destino: proyecto Everfit, tabla tipo_de_cambio.

Requiere en .env:
  - SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (proyecto Everfit, donde se escribe)
  - SUPABASE_ORIGEN_TC_URL + SUPABASE_ORIGEN_TC_SERVICE_ROLE_KEY (proyecto Sistema-Contable-Nuevo)
  En Sistema-Contable-Nuevo la tabla tiene RLS solo para authenticated; por eso se usa service_role para leer.

Uso (desde la raíz del proyecto):
  python scripts/sync_tipo_de_cambio_desde_origen.py
"""
import os
from pathlib import Path

from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

# Tabla en el proyecto origen (Sistema-Contable-Nuevo)
TABLA_ORIGEN = "tipos_cambio_global"


def main():
    url_everfit = os.getenv("SUPABASE_URL")
    key_everfit = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    url_origen = os.getenv("SUPABASE_ORIGEN_TC_URL")
    key_origen = os.getenv("SUPABASE_ORIGEN_TC_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ORIGEN_TC_ANON_KEY")

    if not url_everfit or not key_everfit:
        print("Faltan SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY en .env (proyecto Everfit)")
        return 1
    if not url_origen or not key_origen:
        print("Faltan SUPABASE_ORIGEN_TC_URL y (SUPABASE_ORIGEN_TC_SERVICE_ROLE_KEY o SUPABASE_ORIGEN_TC_ANON_KEY) en .env")
        return 1

    try:
        from supabase import create_client
    except ImportError:
        print("Instala: pip install -r requirements-migracion.txt")
        return 1

    client_origen = create_client(url_origen, key_origen)
    client_everfit = create_client(url_everfit, key_everfit)

    # Leer tipos_cambio_global del proyecto origen (Sistema-Contable-Nuevo)
    try:
        res = client_origen.table(TABLA_ORIGEN).select("fecha, usd_mep, usd_ccl, usd_oficial").order("fecha").execute()
    except Exception as e:
        print(f"Error leyendo {TABLA_ORIGEN} del proyecto origen:", e)
        return 1

    filas = res.data or []
    if not filas:
        print(f"El proyecto origen no devolvió filas en {TABLA_ORIGEN}. Revisá URL, clave (service_role para Sistema-Contable-Nuevo) y RLS.")
        return 0

    # Normalizar: fecha como string YYYY-MM-DD para upsert
    rows_everfit = []
    for r in filas:
        f = r.get("fecha")
        if not f:
            continue
        if hasattr(f, "isoformat"):
            f = f.isoformat()[:10]
        else:
            f = str(f)[:10]
        rows_everfit.append({
            "fecha": f,
            "usd_mep": r.get("usd_mep"),
            "usd_ccl": r.get("usd_ccl"),
            "usd_oficial": r.get("usd_oficial"),
        })

    try:
        # Upsert por fecha (evita duplicados). Requiere UNIQUE(fecha) en tipo_de_cambio.
        client_everfit.table("tipo_de_cambio").upsert(rows_everfit, on_conflict="fecha").execute()
        print(f"Sync OK: {len(rows_everfit)} filas de {TABLA_ORIGEN} → tipo_de_cambio en Everfit.")
    except Exception as e:
        print("Error escribiendo en Everfit:", e)
        return 1
    return 0


if __name__ == "__main__":
    exit(main())
