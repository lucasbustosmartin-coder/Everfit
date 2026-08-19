-- To-Do bandeja: emails de responsable (usuario) y quien cambió el estado (para tooltip + copiar).

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
