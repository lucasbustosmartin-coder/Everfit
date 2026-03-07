-- Ejecutar en el proyecto Sistema-Contable-Nuevo (Supabase SQL Editor).
-- Permite que clientes anónimos lean la tabla tipos_cambio_global (solo SELECT).
-- Así Everfit puede consumir tipos de cambio por API (Opción 2) usando la anon key del origen.

ALTER TABLE IF EXISTS public.tipos_cambio_global ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tipos_cambio_global_select_anon" ON public.tipos_cambio_global;
CREATE POLICY "tipos_cambio_global_select_anon"
  ON public.tipos_cambio_global FOR SELECT TO anon
  USING (true);
