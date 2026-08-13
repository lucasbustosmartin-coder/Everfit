-- Permisos editar / eliminar To-Do (configurables por rol en Seguridad).
-- Prerrequisito: sql/supabase_todo.sql

INSERT INTO public.app_permission (permission, description) VALUES
  ('editar_todo', 'Editar tareas del To-Do'),
  ('eliminar_todo', 'Eliminar tareas del To-Do')
ON CONFLICT (permission) DO UPDATE SET description = EXCLUDED.description;

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'editar_todo'),
  ('admin', 'eliminar_todo'),
  ('encargado', 'editar_todo'),
  ('encargado', 'eliminar_todo')
ON CONFLICT (role, permission) DO NOTHING;

CREATE OR REPLACE FUNCTION public.todo_editar_instancia(
  p_instancia_id uuid,
  p_titulo text DEFAULT NULL,
  p_descripcion text DEFAULT NULL,
  p_prioridad smallint DEFAULT NULL,
  p_vencimiento_at timestamptz DEFAULT NULL,
  p_sede text DEFAULT NULL,
  p_actualizar_plantilla boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  i public.todo_instancia%ROWTYPE;
  v_titulo text;
  v_desc text;
  v_prio smallint;
  v_venc timestamptz;
  v_sede text;
BEGIN
  IF NOT public.has_permission('editar_todo') THEN
    RAISE EXCEPTION 'Sin permiso para editar tareas';
  END IF;

  SELECT * INTO i FROM public.todo_instancia WHERE id = p_instancia_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tarea no encontrada';
  END IF;

  IF NOT public.todo_puede_ver_instancia(i) THEN
    RAISE EXCEPTION 'Sin acceso a esta tarea';
  END IF;

  v_titulo := COALESCE(NULLIF(btrim(COALESCE(p_titulo, '')), ''), i.titulo);
  v_desc := CASE
    WHEN p_descripcion IS NULL THEN i.descripcion
    ELSE NULLIF(btrim(p_descripcion), '')
  END;
  v_prio := COALESCE(p_prioridad, i.prioridad);
  IF v_prio NOT BETWEEN 1 AND 3 THEN
    RAISE EXCEPTION 'Prioridad inválida';
  END IF;
  v_venc := COALESCE(p_vencimiento_at, i.vencimiento_at);
  v_sede := CASE
    WHEN p_sede IS NULL THEN i.sede
    WHEN btrim(p_sede) = '' THEN NULL
    ELSE btrim(p_sede)
  END;

  UPDATE public.todo_instancia
  SET
    titulo = v_titulo,
    descripcion = v_desc,
    prioridad = v_prio,
    vencimiento_at = v_venc,
    sede = v_sede,
    updated_at = now()
  WHERE id = p_instancia_id;

  IF COALESCE(p_actualizar_plantilla, false) AND i.tarea_id IS NOT NULL THEN
    UPDATE public.todo_tarea
    SET
      titulo = v_titulo,
      descripcion = v_desc,
      prioridad = v_prio,
      updated_at = now()
    WHERE id = i.tarea_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_eliminar_instancia(
  p_instancia_id uuid,
  p_eliminar_plantilla boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  i public.todo_instancia%ROWTYPE;
  tid uuid;
BEGIN
  IF NOT public.has_permission('eliminar_todo') THEN
    RAISE EXCEPTION 'Sin permiso para eliminar tareas';
  END IF;

  SELECT * INTO i FROM public.todo_instancia WHERE id = p_instancia_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tarea no encontrada';
  END IF;

  IF NOT public.todo_puede_ver_instancia(i) THEN
    RAISE EXCEPTION 'Sin acceso a esta tarea';
  END IF;

  tid := i.tarea_id;
  DELETE FROM public.todo_instancia WHERE id = p_instancia_id;

  IF COALESCE(p_eliminar_plantilla, false) AND tid IS NOT NULL THEN
    UPDATE public.todo_tarea SET activa = false, updated_at = now() WHERE id = tid;
    DELETE FROM public.todo_instancia
    WHERE tarea_id = tid
      AND estado IN ('pendiente', 'en_curso');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_editar_instancia(uuid, text, text, smallint, timestamptz, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_eliminar_instancia(uuid, boolean) TO authenticated;
