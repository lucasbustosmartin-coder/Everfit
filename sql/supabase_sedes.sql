-- =============================================================================
-- Catálogo de sedes (ABM) + listado unificado para permisos / To-Do
-- Prerrequisito: supabase_seguridad.sql, supabase_sucursales_por_usuario.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.sedes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  activa boolean NOT NULL DEFAULT true,
  orden smallint NOT NULL DEFAULT 100,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sedes_nombre_no_vacio CHECK (length(trim(nombre)) > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_sedes_nombre_ci
  ON public.sedes (lower(trim(nombre)));

CREATE INDEX IF NOT EXISTS idx_sedes_activa_orden ON public.sedes (activa, orden, nombre);

COMMENT ON TABLE public.sedes IS 'Catálogo de sedes/sucursales para permisos, filtros y To-Do.';

-- Semilla desde base_everfit (si aún no hay filas)
INSERT INTO public.sedes (nombre, activa, orden)
SELECT d.sucursal, true, 100
FROM (
  SELECT DISTINCT trim(sucursal) AS sucursal
  FROM public.base_everfit
  WHERE sucursal IS NOT NULL AND trim(sucursal) <> ''
) d
WHERE NOT EXISTS (SELECT 1 FROM public.sedes s WHERE lower(s.nombre) = lower(d.sucursal))
ON CONFLICT DO NOTHING;

-- Si no había datos en base, asegurar las 3 sedes conocidas
INSERT INTO public.sedes (nombre, activa, orden) VALUES
  ('Cabildo', true, 10),
  ('Cramer', true, 20),
  ('Migueletes', true, 30)
ON CONFLICT DO NOTHING;

-- Upsert por nombre (el unique es functional; ON CONFLICT DO NOTHING arriba puede no disparar)
INSERT INTO public.sedes (nombre, activa, orden)
SELECT v.nombre, true, v.orden
FROM (VALUES
  ('Cabildo', 10),
  ('Cramer', 20),
  ('Migueletes', 30)
) AS v(nombre, orden)
WHERE NOT EXISTS (
  SELECT 1 FROM public.sedes s WHERE lower(trim(s.nombre)) = lower(v.nombre)
);

ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sedes_select_authenticated ON public.sedes;
CREATE POLICY sedes_select_authenticated ON public.sedes
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS sedes_write_admin ON public.sedes;
CREATE POLICY sedes_write_admin ON public.sedes
  FOR ALL TO authenticated
  USING (public.has_permission('assign_roles'))
  WITH CHECK (public.has_permission('assign_roles'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.sedes TO authenticated;

-- Listado para Seguridad / filtros: preferir catálogo activo; si vacío, fallback base_everfit
CREATE OR REPLACE FUNCTION public.get_sucursales_list()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN EXISTS (SELECT 1 FROM public.sedes WHERE activa) THEN
      COALESCE((
        SELECT array_agg(nombre ORDER BY orden, nombre)
        FROM public.sedes
        WHERE activa
      ), ARRAY[]::text[])
    ELSE
      COALESCE((
        SELECT array_agg(sucursal ORDER BY sucursal)
        FROM (
          SELECT DISTINCT trim(sucursal) AS sucursal
          FROM public.base_everfit
          WHERE sucursal IS NOT NULL AND trim(sucursal) <> ''
        ) t
      ), ARRAY[]::text[])
  END;
$$;

CREATE OR REPLACE FUNCTION public.sedes_list_admin(p_incluir_inactivas boolean DEFAULT true)
RETURNS TABLE (
  id uuid,
  nombre text,
  activa boolean,
  orden smallint,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT s.id, s.nombre, s.activa, s.orden, s.created_at, s.updated_at
  FROM public.sedes s
  WHERE p_incluir_inactivas OR s.activa
  ORDER BY s.orden, s.nombre;
END;
$$;

CREATE OR REPLACE FUNCTION public.sedes_upsert(
  p_nombre text,
  p_activa boolean DEFAULT true,
  p_orden smallint DEFAULT 100,
  p_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_nombre text;
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para administrar sedes';
  END IF;
  v_nombre := btrim(COALESCE(p_nombre, ''));
  IF v_nombre = '' THEN
    RAISE EXCEPTION 'El nombre de la sede es obligatorio';
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE public.sedes
    SET
      nombre = v_nombre,
      activa = COALESCE(p_activa, activa),
      orden = COALESCE(p_orden, orden),
      updated_at = now()
    WHERE id = p_id
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN
      RAISE EXCEPTION 'Sede no encontrada';
    END IF;
    RETURN v_id;
  END IF;

  IF EXISTS (SELECT 1 FROM public.sedes s WHERE lower(trim(s.nombre)) = lower(v_nombre)) THEN
    RAISE EXCEPTION 'Ya existe una sede con ese nombre';
  END IF;

  INSERT INTO public.sedes (nombre, activa, orden)
  VALUES (v_nombre, COALESCE(p_activa, true), COALESCE(p_orden, 100))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sedes_set_activa(p_id uuid, p_activa boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para administrar sedes';
  END IF;
  UPDATE public.sedes
  SET activa = COALESCE(p_activa, false), updated_at = now()
  WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sede no encontrada';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sedes_delete(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para administrar sedes';
  END IF;
  -- Baja lógica: no romper historial de To-Do / permisos por nombre
  UPDATE public.sedes
  SET activa = false, updated_at = now()
  WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sede no encontrada';
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sucursales_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.sedes_list_admin(boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sedes_upsert(text, boolean, smallint, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sedes_set_activa(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sedes_delete(uuid) TO authenticated;

COMMENT ON FUNCTION public.get_sucursales_list() IS 'Sedes activas del catálogo (fallback: distinct base_everfit).';
COMMENT ON FUNCTION public.sedes_list_admin(boolean) IS 'ABM sedes: listado (solo Admin assign_roles).';
COMMENT ON FUNCTION public.sedes_upsert(text, boolean, smallint, uuid) IS 'ABM sedes: alta/edición.';
COMMENT ON FUNCTION public.sedes_set_activa(uuid, boolean) IS 'ABM sedes: activar/desactivar.';
COMMENT ON FUNCTION public.sedes_delete(uuid) IS 'ABM sedes: baja lógica (activa=false).';
