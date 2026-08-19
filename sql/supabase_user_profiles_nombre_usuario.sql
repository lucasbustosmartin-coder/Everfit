-- Nombre de usuario visible (perfil): reemplaza el email en bandeja To-Do, combos y barra superior.
-- Ejecutar después de supabase_seguridad.sql.

ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS nombre_usuario text;

COMMENT ON COLUMN public.user_profiles.nombre_usuario IS
  'Nombre para mostrar en la app; si está vacío se usa el email.';

CREATE OR REPLACE FUNCTION public.user_profile_label(p_nombre text, p_email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
  SELECT COALESCE(NULLIF(btrim(p_nombre), ''), NULLIF(btrim(p_email), ''), '');
$$;

GRANT EXECUTE ON FUNCTION public.user_profile_label(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (email text, nombre_usuario text, label text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.email,
    p.nombre_usuario,
    public.user_profile_label(p.nombre_usuario, p.email)
  FROM public.user_profiles p
  WHERE p.id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

CREATE OR REPLACE FUNCTION public.set_user_nombre_usuario(p_user_id uuid, p_nombre text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_nombre text;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuario inválido';
  END IF;

  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para editar este usuario';
  END IF;

  v_nombre := NULLIF(btrim(p_nombre), '');
  IF v_nombre IS NOT NULL AND char_length(v_nombre) > 80 THEN
    RAISE EXCEPTION 'El nombre no puede superar 80 caracteres';
  END IF;

  UPDATE public.user_profiles
  SET nombre_usuario = v_nombre
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    INSERT INTO public.user_profiles (id, email, nombre_usuario)
    VALUES (
      p_user_id,
      COALESCE((SELECT u.email FROM auth.users u WHERE u.id = p_user_id), ''),
      v_nombre
    )
    ON CONFLICT (id) DO UPDATE SET nombre_usuario = EXCLUDED.nombre_usuario;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_user_nombre_usuario(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_nombre_usuario(p_nombre text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.set_user_nombre_usuario(auth.uid(), p_nombre);
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_my_nombre_usuario(text) TO authenticated;

-- Admin: listado con nombre visible
DROP FUNCTION IF EXISTS public.get_users_for_admin();
CREATE OR REPLACE FUNCTION public.get_users_for_admin()
RETURNS TABLE (
  user_id uuid,
  email text,
  nombre_usuario text,
  label text,
  role text,
  sucursales_permitidas text[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p.id,
    p.email,
    p.nombre_usuario,
    public.user_profile_label(p.nombre_usuario, p.email),
    COALESCE(u.role, 'visor'),
    u.sucursales_permitidas
  FROM public.user_profiles p
  LEFT JOIN public.app_user_profile u ON u.user_id = p.id
  WHERE public.has_permission('assign_roles');
$$;

GRANT EXECUTE ON FUNCTION public.get_users_for_admin() TO authenticated;

-- To-Do: combos con label visible
DROP FUNCTION IF EXISTS public.todo_list_usuarios();
CREATE OR REPLACE FUNCTION public.todo_list_usuarios()
RETURNS TABLE (
  user_id uuid,
  email text,
  nombre_usuario text,
  label text,
  role text,
  role_label text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('crear_todo') THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.email,
    p.nombre_usuario,
    public.user_profile_label(p.nombre_usuario, p.email),
    COALESCE(u.role, 'visor'),
    COALESCE(r.label, COALESCE(u.role, 'visor'))
  FROM public.user_profiles p
  LEFT JOIN public.app_user_profile u ON u.user_id = p.id
  LEFT JOIN public.app_role r ON r.role = u.role
  ORDER BY public.user_profile_label(p.nombre_usuario, p.email), p.email;
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_list_usuarios() TO authenticated;

DROP FUNCTION IF EXISTS public.todo_list_hechas_hoy(smallint, text);
CREATE OR REPLACE FUNCTION public.todo_list_hechas_hoy(
  p_prioridad smallint DEFAULT NULL,
  p_sede text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  titulo text,
  descripcion text,
  responsable_label text,
  completada_at timestamptz,
  sede text,
  prioridad smallint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  my_role text;
  can_all boolean;
  hoy date;
  my_suc text[];
BEGIN
  IF NOT public.has_permission('ver_todo') THEN
    RETURN;
  END IF;

  my_role := public.get_my_role();
  can_all := public.has_permission('crear_todo');
  hoy := public.fecha_hoy_argentina();
  my_suc := public.get_my_allowed_sucursales();

  RETURN QUERY
  SELECT
    i.id,
    i.titulo,
    i.descripcion,
    CASE
      WHEN i.responsable_tipo = 'rol' THEN COALESCE(ar.label, i.responsable_role)
      ELSE COALESCE(
        public.user_profile_label(up.nombre_usuario, up.email),
        i.responsable_user_id::text
      )
    END AS responsable_label,
    i.completada_at,
    i.sede,
    i.prioridad
  FROM public.todo_instancia i
  LEFT JOIN public.app_role ar ON ar.role = i.responsable_role
  LEFT JOIN public.user_profiles up ON up.id = i.responsable_user_id
  WHERE
    i.estado = 'hecha'
    AND i.completada_at IS NOT NULL
    AND (i.completada_at AT TIME ZONE 'America/Argentina/Buenos_Aires')::date = hoy
    AND (
      can_all
      OR (i.responsable_tipo = 'usuario' AND i.responsable_user_id = auth.uid())
      OR (i.responsable_tipo = 'rol' AND i.responsable_role = my_role)
    )
    AND (
      my_suc IS NULL OR coalesce(array_length(my_suc, 1), 0) = 0
      OR i.sede IS NULL
      OR i.sede = ANY (my_suc)
    )
    AND (p_prioridad IS NULL OR i.prioridad = p_prioridad)
    AND (p_sede IS NULL OR btrim(p_sede) = '' OR i.sede = btrim(p_sede));
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_list_hechas_hoy(smallint, text) TO authenticated;

DROP FUNCTION IF EXISTS public.todo_list_inbox(text, smallint, text, text);
CREATE OR REPLACE FUNCTION public.todo_list_inbox(
  p_estado text DEFAULT NULL,
  p_prioridad smallint DEFAULT NULL,
  p_ventana text DEFAULT 'todas',
  p_sede text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  tarea_id uuid,
  titulo text,
  descripcion text,
  prioridad smallint,
  responsable_tipo text,
  responsable_user_id uuid,
  responsable_role text,
  responsable_label text,
  responsable_email text,
  vencimiento_at timestamptz,
  estado text,
  estado_efectivo text,
  recurrencia text,
  sede text,
  completada_at timestamptz,
  estado_modificado_por uuid,
  estado_modificado_label text,
  estado_modificado_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  my_role text;
  can_all boolean;
  hoy date;
  desde timestamptz;
  hasta timestamptz;
  my_suc text[];
BEGIN
  IF NOT public.has_permission('ver_todo') THEN
    RETURN;
  END IF;

  my_role := public.get_my_role();
  can_all := public.has_permission('crear_todo');
  hoy := public.fecha_hoy_argentina();
  my_suc := public.get_my_allowed_sucursales();

  IF p_ventana = 'hoy' THEN
    desde := public.todo_ts_argentina(hoy, time '00:00');
    hasta := public.todo_ts_argentina(hoy, time '23:59:59');
  ELSIF p_ventana = 'semana' THEN
    desde := public.todo_ts_argentina(hoy, time '00:00');
    hasta := public.todo_ts_argentina(hoy + 7, time '23:59:59');
  ELSIF p_ventana = 'vencidas' THEN
    desde := NULL;
    hasta := now();
  ELSE
    desde := NULL;
    hasta := NULL;
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.tarea_id,
    i.titulo,
    i.descripcion,
    i.prioridad,
    i.responsable_tipo,
    i.responsable_user_id,
    i.responsable_role,
    CASE
      WHEN i.responsable_tipo = 'rol' THEN COALESCE(ar.label, i.responsable_role)
      ELSE COALESCE(
        public.user_profile_label(up.nombre_usuario, up.email),
        i.responsable_user_id::text
      )
    END AS responsable_label,
    CASE
      WHEN i.responsable_tipo = 'usuario' THEN NULLIF(btrim(up.email), '')
      ELSE NULL
    END AS responsable_email,
    i.vencimiento_at,
    i.estado,
    CASE
      WHEN i.estado = 'pendiente' AND i.vencimiento_at < now() THEN 'vencida'
      ELSE i.estado
    END AS estado_efectivo,
    COALESCE(t.recurrencia, 'ninguna') AS recurrencia,
    i.sede,
    i.completada_at,
    i.estado_modificado_por,
    COALESCE(
      public.user_profile_label(up_mod.nombre_usuario, up_mod.email),
      i.estado_modificado_por::text
    ) AS estado_modificado_label,
    NULLIF(btrim(up_mod.email), '') AS estado_modificado_email,
    i.created_at
  FROM public.todo_instancia i
  LEFT JOIN public.todo_tarea t ON t.id = i.tarea_id
  LEFT JOIN public.app_role ar ON ar.role = i.responsable_role
  LEFT JOIN public.user_profiles up ON up.id = i.responsable_user_id
  LEFT JOIN public.user_profiles up_mod ON up_mod.id = i.estado_modificado_por
  WHERE
    (
      can_all
      OR (i.responsable_tipo = 'usuario' AND i.responsable_user_id = auth.uid())
      OR (i.responsable_tipo = 'rol' AND i.responsable_role = my_role)
    )
    AND (
      my_suc IS NULL OR coalesce(array_length(my_suc, 1), 0) = 0
      OR i.sede IS NULL
      OR i.sede = ANY (my_suc)
    )
    AND (p_prioridad IS NULL OR i.prioridad = p_prioridad)
    AND (p_sede IS NULL OR btrim(p_sede) = '' OR i.sede = btrim(p_sede))
    AND (
      (p_estado IS NULL AND i.estado <> 'cancelada')
      OR (p_estado = 'abiertas' AND i.estado IN ('pendiente', 'en_curso'))
      OR (
        p_estado = 'vencida'
        AND i.estado = 'pendiente'
        AND i.vencimiento_at < now()
      )
      OR (
        p_estado IS NOT NULL
        AND p_estado NOT IN ('vencida', 'abiertas')
        AND i.estado = p_estado
      )
    )
    AND (
      p_ventana IS NULL OR p_ventana = 'todas'
      OR (p_ventana = 'hoy' AND i.vencimiento_at >= desde AND i.vencimiento_at <= hasta)
      OR (p_ventana = 'semana' AND i.vencimiento_at >= desde AND i.vencimiento_at <= hasta)
      OR (
        p_ventana = 'vencidas'
        AND i.estado = 'pendiente'
        AND i.vencimiento_at < now()
      )
    )
  ORDER BY
    CASE
      WHEN i.estado = 'pendiente' AND i.vencimiento_at < now() THEN 0
      WHEN i.estado = 'en_curso' THEN 1
      WHEN i.estado = 'pendiente' THEN 2
      WHEN i.estado = 'hecha' THEN 3
      ELSE 4
    END,
    i.vencimiento_at ASC NULLS LAST,
    i.prioridad ASC,
    i.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_list_inbox(text, smallint, text, text) TO authenticated;
