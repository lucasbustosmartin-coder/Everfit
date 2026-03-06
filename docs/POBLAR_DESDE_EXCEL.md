# Volcar Base_Everfit.xlsx a Supabase

Si la base ya tiene la tabla creada y querés **repoblar** desde el Excel (por datos incorrectos o actualización del archivo):

## Requisitos

- Archivo **`Base/Base_Everfit.xlsx`** con la hoja **"Base"** (mismas columnas que al diseñar el script).
- Archivo **`.env`** en la raíz con:
  - `SUPABASE_URL` = URL del proyecto Supabase
  - `SUPABASE_SERVICE_ROLE_KEY` = clave service_role (recomendado para insertar)

## Pasos

### 1. (Opcional) Vaciar la tabla en Supabase

Si querés reemplazar todo lo que hay en `base_everfit`:

En el **SQL Editor** de Supabase, ejecutá el contenido de:

**`sql/supabase_vaciar_base.sql`**

(Trunca la tabla. Si falla por restricciones, usá `DELETE FROM public.base_everfit;`.)

### 2. Ejecutar el script de volcado

En la terminal: **entrá a la raíz del proyecto** y ejecutá:

```bash
cd "/Users/lucasb/Escritorio - MacBook Air de Lucas/Everfit"
python scripts/volcar_excel_a_supabase.py
```

(Si ya estás en la carpeta Everfit, solo: `python scripts/volcar_excel_a_supabase.py`.)

El script lee la hoja "Base" de `Base/Base_Everfit.xlsx`, mapea las columnas a `base_everfit` e inserta por lotes.

---

**Resumen:** 1) (Opcional) Ejecutar `sql/supabase_vaciar_base.sql` en Supabase. 2) Ejecutar `python scripts/volcar_excel_a_supabase.py` desde la raíz.
