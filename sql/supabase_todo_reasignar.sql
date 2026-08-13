-- Configuración: reasignar tareas To-Do de un usuario a otro o de un perfil a otro.
-- Prerrequisito: sql/supabase_todo.sql + sql/supabase_todo_editar_eliminar.sql

INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_configuracion', 'Menú Configuración (reasignar tareas To-Do)')
ON CONFLICT (permission) DO UPDATE SET description = EXCLUDED.description;

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'ver_configuracion'),
  ('encargado', 'ver_configuracion')
ON CONFLICT (role, permission) DO NOTHING;

CREATE OR REPLACE FUNCTION public.todo_list_usuarios()
RETURNS TABLE (user_id uuid, email text, role text, role_label text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (
    public.has_permission('crear_todo')
    OR public.has_permission('ver_configuracion')
  ) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT p.id, p.email, COALESCE(u.role, 'visor'), COALESCE(r.label, COALESCE(u.role, 'visor'))
  FROM public.user_profiles p
  LEFT JOIN public.app_user_profile u ON u.user_id = p.id
  LEFT JOIN public.app_role r ON r.role = u.role
  ORDER BY p.email;
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_list_roles()
RETURNS TABLE (role text, label text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT (
    public.has_permission('crear_todo')
    OR public.has_permission('ver_configuracion')
  ) THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT r.role, r.label FROM public.app_role r
  ORDER BY (
    CASE r.role
      WHEN 'admin' THEN 1
      WHEN 'encargado' THEN 2
      WHEN 'recepcionista' THEN 3
      WHEN 'profesor' THEN 4
      WHEN 'visor' THEN 5
      ELSE 6
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_list_para_reasignar(
  p_tipo text,
  p_from_user_id uuid DEFAULT NULL,
  p_from_role text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  tarea_id uuid,
  titulo text,
  descripcion text,
  prioridad smallint,
  vencimiento_at timestamptz,
  estado text,
  estado_efectivo text,
  recurrencia text,
  sede text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('ver_configuracion') THEN
    RAISE EXCEPTION 'Sin permiso para Configuración';
  END IF;
  IF p_tipo NOT IN ('usuario', 'rol') THEN
    RAISE EXCEPTION 'Tipo inválido';
  END IF;
  IF p_tipo = 'usuario' AND p_from_user_id IS NULL THEN
    RAISE EXCEPTION 'Indicá el usuario de origen';
  END IF;
  IF p_tipo = 'rol' AND (p_from_role IS NULL OR btrim(p_from_role) = '') THEN
    RAISE EXCEPTION 'Indicá el perfil de origen';
  END IF;

  RETURN QUERY
  SELECT
    i.id,
    i.tarea_id,
    i.titulo,
    i.descripcion,
    i.prioridad,
    i.vencimiento_at,
    i.estado,
    CASE
      WHEN i.estado IN ('pendiente', 'en_curso') AND i.vencimiento_at < now() THEN 'vencida'
      ELSE i.estado
    END AS estado_efectivo,
    COALESCE(t.recurrencia, 'ninguna') AS recurrencia,
    i.sede
  FROM public.todo_instancia i
  LEFT JOIN public.todo_tarea t ON t.id = i.tarea_id
  WHERE i.estado IN ('pendiente', 'en_curso')
    AND (
      (p_tipo = 'usuario' AND i.responsable_tipo = 'usuario' AND i.responsable_user_id = p_from_user_id)
      OR (p_tipo = 'rol' AND i.responsable_tipo = 'rol' AND i.responsable_role = btrim(p_from_role))
    )
  ORDER BY i.vencimiento_at ASC NULLS LAST, i.prioridad ASC, i.created_at ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_reasignar(
  p_tipo text,
  p_from_user_id uuid DEFAULT NULL,
  p_to_user_id uuid DEFAULT NULL,
  p_from_role text DEFAULT NULL,
  p_to_role text DEFAULT NULL,
  p_instancia_ids uuid[] DEFAULT NULL,
  p_todas boolean DEFAULT false
)
RETURNS TABLE (instancias integer, plantillas integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_ids uuid[];
  v_n_inst int := 0;
  v_n_plant int := 0;
  v_from_role text;
  v_to_role text;
BEGIN
  IF NOT public.has_permission('ver_configuracion') THEN
    RAISE EXCEPTION 'Sin permiso para Configuración';
  END IF;
  IF p_tipo NOT IN ('usuario', 'rol') THEN
    RAISE EXCEPTION 'Tipo inválido';
  END IF;

  IF p_tipo = 'usuario' THEN
    IF p_from_user_id IS NULL OR p_to_user_id IS NULL THEN
      RAISE EXCEPTION 'Indicá usuario de origen y destino';
    END IF;
    IF p_from_user_id = p_to_user_id THEN
      RAISE EXCEPTION 'El destino debe ser distinto al origen';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = p_from_user_id) THEN
      RAISE EXCEPTION 'Usuario de origen no encontrado';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = p_to_user_id) THEN
      RAISE EXCEPTION 'Usuario de destino no encontrado';
    END IF;
  ELSE
    v_from_role := NULLIF(btrim(COALESCE(p_from_role, '')), '');
    v_to_role := NULLIF(btrim(COALESCE(p_to_role, '')), '');
    IF v_from_role IS NULL OR v_to_role IS NULL THEN
      RAISE EXCEPTION 'Indicá perfil de origen y destino';
    END IF;
    IF v_from_role = v_to_role THEN
      RAISE EXCEPTION 'El destino debe ser distinto al origen';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.app_role WHERE role = v_from_role) THEN
      RAISE EXCEPTION 'Perfil de origen no encontrado';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.app_role WHERE role = v_to_role) THEN
      RAISE EXCEPTION 'Perfil de destino no encontrado';
    END IF;
  END IF;

  IF COALESCE(p_todas, false) THEN
    SELECT COALESCE(array_agg(i.id), ARRAY[]::uuid[]) INTO v_ids
    FROM public.todo_instancia i
    WHERE i.estado IN ('pendiente', 'en_curso')
      AND (
        (p_tipo = 'usuario' AND i.responsable_tipo = 'usuario' AND i.responsable_user_id = p_from_user_id)
        OR (p_tipo = 'rol' AND i.responsable_tipo = 'rol' AND i.responsable_role = v_from_role)
      );
  ELSE
    v_ids := COALESCE(p_instancia_ids, ARRAY[]::uuid[]);
  END IF;

  IF v_ids IS NULL OR coalesce(array_length(v_ids, 1), 0) = 0 THEN
    IF COALESCE(p_todas, false) THEN
      -- Puede no haber ocurrencias abiertas; igual mover plantillas
      v_ids := ARRAY[]::uuid[];
    ELSE
      RAISE EXCEPTION 'No hay tareas para reasignar';
    END IF;
  END IF;

  IF coalesce(array_length(v_ids, 1), 0) > 0 THEN
    IF p_tipo = 'usuario' THEN
      UPDATE public.todo_instancia i
      SET
        responsable_tipo = 'usuario',
        responsable_user_id = p_to_user_id,
        responsable_role = NULL,
        updated_at = now()
      WHERE i.id = ANY (v_ids)
        AND i.estado IN ('pendiente', 'en_curso')
        AND i.responsable_tipo = 'usuario'
        AND i.responsable_user_id = p_from_user_id;
    ELSE
      UPDATE public.todo_instancia i
      SET
        responsable_tipo = 'rol',
        responsable_user_id = NULL,
        responsable_role = v_to_role,
        updated_at = now()
      WHERE i.id = ANY (v_ids)
        AND i.estado IN ('pendiente', 'en_curso')
        AND i.responsable_tipo = 'rol'
        AND i.responsable_role = v_from_role;
    END IF;
    GET DIAGNOSTICS v_n_inst = ROW_COUNT;
  END IF;

  IF COALESCE(p_todas, false) THEN
    IF p_tipo = 'usuario' THEN
      UPDATE public.todo_tarea t
      SET
        responsable_tipo = 'usuario',
        responsable_user_id = p_to_user_id,
        responsable_role = NULL,
        updated_at = now()
      WHERE t.responsable_tipo = 'usuario'
        AND t.responsable_user_id = p_from_user_id
        AND t.activa;
    ELSE
      UPDATE public.todo_tarea t
      SET
        responsable_tipo = 'rol',
        responsable_user_id = NULL,
        responsable_role = v_to_role,
        updated_at = now()
      WHERE t.responsable_tipo = 'rol'
        AND t.responsable_role = v_from_role
        AND t.activa;
    END IF;
    GET DIAGNOSTICS v_n_plant = ROW_COUNT;
  ELSIF coalesce(array_length(v_ids, 1), 0) > 0 THEN
    IF p_tipo = 'usuario' THEN
      UPDATE public.todo_tarea t
      SET
        responsable_tipo = 'usuario',
        responsable_user_id = p_to_user_id,
        responsable_role = NULL,
        updated_at = now()
      WHERE t.activa
        AND t.responsable_tipo = 'usuario'
        AND t.responsable_user_id = p_from_user_id
        AND t.id IN (SELECT DISTINCT i.tarea_id FROM public.todo_instancia i WHERE i.id = ANY (v_ids) AND i.tarea_id IS NOT NULL)
        AND NOT EXISTS (
          SELECT 1 FROM public.todo_instancia x
          WHERE x.tarea_id = t.id
            AND x.estado IN ('pendiente', 'en_curso')
            AND x.responsable_tipo = 'usuario'
            AND x.responsable_user_id = p_from_user_id
        );
    ELSE
      UPDATE public.todo_tarea t
      SET
        responsable_tipo = 'rol',
        responsable_user_id = NULL,
        responsable_role = v_to_role,
        updated_at = now()
      WHERE t.activa
        AND t.responsable_tipo = 'rol'
        AND t.responsable_role = v_from_role
        AND t.id IN (SELECT DISTINCT i.tarea_id FROM public.todo_instancia i WHERE i.id = ANY (v_ids) AND i.tarea_id IS NOT NULL)
        AND NOT EXISTS (
          SELECT 1 FROM public.todo_instancia x
          WHERE x.tarea_id = t.id
            AND x.estado IN ('pendiente', 'en_curso')
            AND x.responsable_tipo = 'rol'
            AND x.responsable_role = v_from_role
        );
    END IF;
    GET DIAGNOSTICS v_n_plant = ROW_COUNT;
  END IF;

  instancias := v_n_inst;
  plantillas := v_n_plant;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_list_usuarios() TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_list_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_list_para_reasignar(text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_reasignar(text, uuid, uuid, text, text, uuid[], boolean) TO authenticated;
