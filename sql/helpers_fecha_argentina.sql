-- Día contable en calendario Argentina (no CURRENT_DATE del servidor).
-- Ver docs/FECHAS_ARGENTINA.md y regla fechas-argentina-negocio.

CREATE OR REPLACE FUNCTION public.fecha_hoy_argentina()
RETURNS date
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT (now() AT TIME ZONE 'America/Argentina/Buenos_Aires')::date;
$$;

COMMENT ON FUNCTION public.fecha_hoy_argentina() IS
  'Día contable YYYY-MM-DD en calendario America/Argentina/Buenos_Aires (no CURRENT_DATE del servidor).';

GRANT EXECUTE ON FUNCTION public.fecha_hoy_argentina() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fecha_hoy_argentina() TO anon;
GRANT EXECUTE ON FUNCTION public.fecha_hoy_argentina() TO service_role;
