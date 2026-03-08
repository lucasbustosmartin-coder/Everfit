-- Sucursales permitidas por usuario (qué sucursales puede ver cada usuario).
-- Ejecutar después de supabase_seguridad.sql y supabase_seguridad_permisos_editable.sql.
-- NULL o array vacío = puede ver todas las sucursales.

ALTER TABLE public.app_user_profile
  ADD COLUMN IF NOT EXISTS sucursales_permitidas text[] DEFAULT NULL;

COMMENT ON COLUMN public.app_user_profile.sucursales_permitidas IS 'Si NULL o vacío: ve todas. Si tiene valores: solo puede ver esas sucursales en el filtro.';

-- RPC: sucursales que el usuario actual puede ver (NULL = todas)
CREATE OR REPLACE FUNCTION public.get_my_allowed_sucursales()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT sucursales_permitidas
  FROM public.app_user_profile
  WHERE user_id = auth.uid();
$$;

-- RPC: listado de sucursales existentes en base_everfit (para Admin y para filtros)
CREATE OR REPLACE FUNCTION public.get_sucursales_list()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(sucursal ORDER BY sucursal), ARRAY[]::text[])
  FROM (
    SELECT DISTINCT trim(sucursal) AS sucursal
    FROM public.base_everfit
    WHERE sucursal IS NOT NULL AND trim(sucursal) <> ''
  ) t;
$$;

-- RPC: Admin asigna sucursales permitidas a un usuario
CREATE OR REPLACE FUNCTION public.set_user_sucursales(p_user_id uuid, p_sucursales text[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para modificar sucursales de usuarios';
  END IF;
  UPDATE public.app_user_profile
  SET sucursales_permitidas = CASE
    WHEN p_sucursales IS NULL OR array_length(p_sucursales, 1) IS NULL THEN NULL
    ELSE p_sucursales
  END
  WHERE user_id = p_user_id;
  IF NOT FOUND THEN
    INSERT INTO public.app_user_profile (user_id, role, sucursales_permitidas)
    SELECT p_user_id, 'visor', p_sucursales
    FROM public.user_profiles WHERE id = p_user_id
    ON CONFLICT (user_id) DO UPDATE SET sucursales_permitidas = EXCLUDED.sucursales_permitidas;
  END IF;
END;
$$;

-- Actualizar get_users_for_admin para devolver sucursales_permitidas (cambia el tipo de retorno)
DROP FUNCTION IF EXISTS public.get_users_for_admin();
CREATE OR REPLACE FUNCTION public.get_users_for_admin()
RETURNS TABLE (user_id uuid, email text, role text, sucursales_permitidas text[])
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p.id, p.email, COALESCE(u.role, 'visor'), u.sucursales_permitidas
  FROM public.user_profiles p
  LEFT JOIN public.app_user_profile u ON u.user_id = p.id
  WHERE public.has_permission('assign_roles');
$$;

GRANT EXECUTE ON FUNCTION public.get_my_allowed_sucursales() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_sucursales_list() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_sucursales(uuid, text[]) TO authenticated;

COMMENT ON FUNCTION public.get_my_allowed_sucursales() IS 'Sucursales que el usuario actual puede ver; NULL = todas.';
COMMENT ON FUNCTION public.get_sucursales_list() IS 'Lista de sucursales distintas en base_everfit.';
COMMENT ON FUNCTION public.set_user_sucursales(uuid, text[]) IS 'Admin: asigna sucursales permitidas a un usuario.';
