# Crear la tabla tipo_de_cambio en Everfit (una sola vez)

La API de Supabase no permite ejecutar CREATE TABLE desde código; hay que hacerlo desde el dashboard.

1. Abrí el **SQL Editor** de tu proyecto Everfit:  
   **https://supabase.com/dashboard/project/skhuplgurhlezobobqrx/sql/new**

2. Pegá y ejecutá el contenido del archivo **`sql/supabase_tipo_de_cambio.sql`** (o el que está abajo).

3. Después ejecutá el sync:  
   `python scripts/sync_tipo_de_cambio_desde_origen.py`

---

SQL a pegar:

```sql
CREATE TABLE IF NOT EXISTS public.tipo_de_cambio (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha date NOT NULL,
  usd_mep numeric,
  usd_ccl numeric,
  usd_oficial numeric,
  creado_en timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tipo_de_cambio_fecha_unique ON public.tipo_de_cambio (fecha);
CREATE INDEX IF NOT EXISTS idx_tipo_de_cambio_fecha ON public.tipo_de_cambio (fecha);

COMMENT ON TABLE public.tipo_de_cambio IS 'Tipos de cambio USD (MEP, CCL, oficial) por fecha. Sincronizado desde proyecto origen o leído por API.';
```
