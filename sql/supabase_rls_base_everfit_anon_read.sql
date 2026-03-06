-- Permitir lectura (SELECT) de base_everfit para anon.
-- Necesario para que el dashboard.html en el navegador pueda leer datos con la clave anon.
-- Ejecutar en Supabase SQL Editor (proyecto Everfit).

ALTER TABLE IF EXISTS public.base_everfit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "base_everfit_select_anon" ON public.base_everfit;
CREATE POLICY "base_everfit_select_anon"
  ON public.base_everfit
  FOR SELECT
  TO anon
  USING (true);
