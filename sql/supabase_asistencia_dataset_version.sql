-- Huella liviana del subconjunto transacciones_asistencia en [p_desde, p_hasta].
-- El dashboard la usa para no re-descargar todas las páginas si el rango UI coincide
-- y los datos en ese rango no cambiaron (p. ej. otra pestaña o nueva sesión).
-- Ejecutar en Supabase SQL Editor (después de supabase_transacciones_asistencia.sql).

CREATE OR REPLACE FUNCTION public.get_asistencia_dataset_version(p_desde date, p_hasta date)
RETURNS text
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT md5(
    coalesce((SELECT count(*)::text FROM public.transacciones_asistencia t WHERE t.fecha >= p_desde AND t.fecha <= p_hasta), '0')
    || '|' || coalesce((SELECT max(t.created_at)::text FROM public.transacciones_asistencia t WHERE t.fecha >= p_desde AND t.fecha <= p_hasta), '')
    || '|' || coalesce((SELECT max(t.fecha)::text FROM public.transacciones_asistencia t WHERE t.fecha >= p_desde AND t.fecha <= p_hasta), '')
  );
$$;

COMMENT ON FUNCTION public.get_asistencia_dataset_version(date, date) IS 'Huella del dataset de asistencia en un rango de fechas; para cache del dashboard.';

GRANT EXECUTE ON FUNCTION public.get_asistencia_dataset_version(date, date) TO authenticated;
