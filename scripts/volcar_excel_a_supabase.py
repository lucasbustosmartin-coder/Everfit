#!/usr/bin/env python3
"""
Volca la hoja "Base" de Base/Base_Everfit.xlsx a la tabla base_everfit en Supabase.
Requiere: .env en la raíz con SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.

Uso (desde la raíz del proyecto):
  python scripts/volcar_excel_a_supabase.py
"""
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

# Raíz del proyecto (carpeta donde están Base/ y scripts/)
RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

EXCEL_PATH = RAIZ / "Base" / "Base_Everfit.xlsx"
HOJA_BASE = "Base"

# Mapeo columnas Excel → columnas tabla Supabase (snake_case)
COLUMNAS_EXCEL_A_DB = {
    "Beneficiario": "beneficiario",
    "Concepto": "concepto",
    "Centro de Costos": "centro_de_costos",
    "Detalle": "detalle",
    "Medio": "medio",
    "Nro de Cheque": "nro_de_cheque",
    "Fecha de Emisión": "fecha_emision",
    "Fecha Original de Pago": "fecha_original_pago",
    "Fecha De Pago": "fecha_pago",
    "Importe": "importe",
    "Observaciones": "observaciones",
    "Orden de Pago": "orden_de_pago",
    "Real - Pendiente": "real_pendiente",
    "Valor": "valor",
    "TC": "tc",
    "Valor USD": "valor_usd",
    "Sucursal": "sucursal",
    "Ingresos-Egresos": "ingresos_egresos",
    "Mes de Pago": "mes_de_pago",
}


def normalizar_valor(val):
    """Convierte NaN, NaT, "-", etc. a None para JSON/Supabase. Fechas/horas a string ISO."""
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return None
    if isinstance(val, str):
        s = val.strip()
        if s == "" or s == "-":
            return None
    try:
        if pd.isna(val):
            return None
    except (TypeError, ValueError):
        pass
    if hasattr(val, "isoformat") and not isinstance(val, type(pd.NaT)):
        try:
            return val.isoformat()
        except (ValueError, AttributeError):
            return str(val)
    return val


def excel_a_filas(archivo: Path, hoja: str) -> list[dict]:
    """Lee la hoja indicada del Excel y devuelve lista de filas para insertar."""
    filas = []
    nombre_archivo = archivo.name
    try:
        df = pd.read_excel(archivo, sheet_name=hoja)
        df = df.rename(columns=lambda c: c.strip() if isinstance(c, str) else c)
        if df.empty or len(df.columns) < 3:
            return filas
        for _, row in df.iterrows():
            rec = {"origen_archivo": nombre_archivo}
            for col_excel, col_db in COLUMNAS_EXCEL_A_DB.items():
                if col_excel not in df.columns:
                    rec[col_db] = None
                    continue
                val = row.get(col_excel)
                rec[col_db] = normalizar_valor(val)
            centro = (rec.get("centro_de_costos") or "").strip().lower()
            if centro == "saldo inicial":
                continue
            filas.append(rec)
    except Exception as e:
        print(f"  Error leyendo {nombre_archivo} hoja '{hoja}': {e}")
    return filas


def main():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    if not url or not key:
        print("Faltan SUPABASE_URL y (SUPABASE_SERVICE_ROLE_KEY o SUPABASE_ANON_KEY) en .env")
        return 1
    if not os.getenv("SUPABASE_SERVICE_ROLE_KEY"):
        print("⚠️  Usando ANON KEY. Si falla por permisos, configura SUPABASE_SERVICE_ROLE_KEY en .env")
        print("   Ver: docs/SUPABASE_REQUISITOS.md\n")

    try:
        from supabase import create_client
    except ImportError:
        print("Instala dependencias: pip install -r requirements-migracion.txt")
        return 1

    client = create_client(url, key)

    if not EXCEL_PATH.exists():
        print("No existe el archivo:", EXCEL_PATH)
        return 1

    print(f"Procesando: {EXCEL_PATH.name} (hoja '{HOJA_BASE}')")
    filas = excel_a_filas(EXCEL_PATH, HOJA_BASE)
    if not filas:
        print("  No se obtuvieron filas. Revisa que la hoja se llame exactamente 'Base'.")
        return 1

    total_insertadas = 0
    batch = 500
    for i in range(0, len(filas), batch):
        chunk = filas[i : i + batch]
        try:
            client.table("base_everfit").insert(chunk).execute()
            total_insertadas += len(chunk)
        except Exception as e:
            print(f"  Error insertando lote: {e}")
            for row in chunk:
                try:
                    client.table("base_everfit").insert(row).execute()
                    total_insertadas += 1
                except Exception as e2:
                    print(f"    Fila fallida: {e2}")
    print(f"  Insertadas: {total_insertadas} filas.")
    return 0


if __name__ == "__main__":
    exit(main())
