# Crear proyecto Supabase y volcar Base Everfit

## Resumen del Excel

- **Archivo:** `Base/Base_Everfit.xlsx`
- **Hoja de datos:** "Base"
- **Columnas principales:** Beneficiario, Concepto, Centro de Costos, Detalle, Medio, Fecha de Emisión, Fecha De Pago, Importe, Observaciones, Sucursal, Ingresos-Egresos, Mes de Pago, etc.

La tabla en Supabase se llama **`base_everfit`** y tiene las mismas columnas en snake_case (ej. `centro_de_costos`, `fecha_pago`).

---

## Pasos para crear el proyecto Supabase y cargar los datos

### 1. Crear proyecto en Supabase

1. Entrá a [supabase.com](https://supabase.com) e iniciá sesión.
2. **New project**: elegí nombre (ej. "everfit"), contraseña de base de datos y región.
3. Esperá a que el proyecto esté listo.

### 2. Obtener URL y API Key

1. En el dashboard: **Project Settings** (ícono engranaje) → **API**.
2. Copiá:
   - **Project URL** (ej. `https://xxxxx.supabase.co`).
   - **Project API Keys** → **service_role** (secret). Usala solo en tu máquina, nunca en el frontend ni en el repo.

### 3. Crear el archivo `.env` en la raíz del proyecto

En la carpeta Everfit (donde están `Base/`, `scripts/`, `sql/`), creá un archivo llamado `.env` con:

```env
SUPABASE_URL=https://TU_PROYECTO.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Reemplazá por tu Project URL y tu service_role key. No subas este archivo a Git (ya está en `.gitignore`).

### 4. Crear la tabla en Supabase

1. En Supabase: **SQL Editor**.
2. Abrí el archivo `sql/supabase_base_everfit.sql` de este repo.
3. Copiá todo su contenido, pegá en el editor y ejecutá (Run).  
   Eso crea la tabla `base_everfit` con todas las columnas e índices.

### 5. Instalar dependencias y ejecutar el script de volcado

En la terminal: **entrá primero a la raíz del proyecto** (donde están `Base/`, `scripts/`, `sql/`) y después ejecutá:

```bash
cd "/Users/lucasb/Escritorio - MacBook Air de Lucas/Everfit"
pip install -r requirements-migracion.txt
python scripts/volcar_excel_a_supabase.py
```

El script lee `Base/Base_Everfit.xlsx`, hoja "Base", y inserta todas las filas en la tabla `base_everfit`.

---

## Resumen rápido

1. Crear proyecto en Supabase.
2. Copiar **Project URL** y **service_role key**.
3. Crear `.env` con `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`.
4. Ejecutar `sql/supabase_base_everfit.sql` en el SQL Editor de Supabase.
5. Ejecutar `pip install -r requirements-migracion.txt` y `python scripts/volcar_excel_a_supabase.py`.

Cuando quieras **repoblar** desde cero (tabla con datos viejos o incorrectos), ejecutá primero en Supabase el contenido de `sql/supabase_vaciar_base.sql` y después volvé a correr el script de volcado.

---

**Tipos de cambio (ARS / USD):** Para tener montos en ambas monedas podés usar la tabla `tipo_de_cambio` leyéndola desde otro proyecto Supabase. Ver `docs/TIPO_DE_CAMBIO_DESDE_OTRO_PROYECTO.md` (sync desde el proyecto origen o lectura directa por API).
