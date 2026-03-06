-- Permitir lectura (SELECT) de tipo_de_cambio para anon.
-- Necesario para que el dashboard pueda mostrar montos en USD (conversión por MEP/CCL/Oficial).
-- Ejecutar en Supabase SQL Editor (proyecto Everfit) si la tabla tiene RLS activado.

ALTER TABLE IF EXISTS public.tipo_de_cambio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tipo_de_cambio_select_anon" ON public.tipo_de_cambio;
CREATE POLICY "tipo_de_cambio_select_anon"
  ON public.tipo_de_cambio
  FOR SELECT
  TO anon
  USING (true);
