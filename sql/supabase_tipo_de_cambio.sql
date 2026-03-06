-- Tabla: tipo_de_cambio
-- Misma estructura que en el proyecto origen (Fornitalia u otro). Se puede poblar por sync desde ese proyecto.
-- Ejecutar en Supabase SQL Editor (proyecto Everfit)

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
