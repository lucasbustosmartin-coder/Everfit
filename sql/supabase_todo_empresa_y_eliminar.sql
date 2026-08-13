-- To-Do: nivel Empresa (una sola instancia sin sede) + eliminación que no se regenera.
-- Prerrequisito: sql/supabase_todo_sede_y_fecha_fin.sql

-- Permite: todas (aplica_todas=true, sede NULL) | una sede | empresa (aplica_todas=false, sede NULL)
ALTER TABLE public.todo_tarea DROP CONSTRAINT IF EXISTS todo_tarea_sede_chk;
ALTER TABLE public.todo_tarea
  ADD CONSTRAINT todo_tarea_sede_chk CHECK (
    (aplica_todas_sedes = true AND sede IS NULL)
    OR (aplica_todas_sedes = false)
  );

COMMENT ON COLUMN public.todo_tarea.aplica_todas_sedes IS
  'true = una instancia por cada sede activa; false + sede = una sede; false + sede NULL = nivel Empresa (una sola tarea).';

CREATE OR REPLACE FUNCTION public.todo_sedes_para_tarea(t public.todo_tarea)
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN t.aplica_todas_sedes THEN
      COALESCE((
        SELECT array_agg(s.nombre ORDER BY s.orden, s.nombre)
        FROM public.sedes s
        WHERE s.activa
      ), ARRAY[]::text[])
    WHEN t.sede IS NOT NULL AND length(trim(t.sede)) > 0 THEN
      ARRAY[trim(t.sede)]
    ELSE
      -- Nivel Empresa: una sola instancia sin sede
      ARRAY[NULL]::text[]
  END;
$$;

CREATE OR REPLACE FUNCTION public.todo_crear_tarea(
  p_titulo text,
  p_descripcion text DEFAULT NULL,
  p_prioridad smallint DEFAULT 2,
  p_responsable_tipo text DEFAULT 'usuario',
  p_responsable_user_id uuid DEFAULT NULL,
  p_responsable_role text DEFAULT NULL,
  p_recurrencia text DEFAULT 'ninguna',
  p_hora_vencimiento time without time zone DEFAULT NULL,
  p_dia_semana smallint DEFAULT NULL,
  p_dia_mes smallint DEFAULT NULL,
  p_fecha_inicio date DEFAULT NULL,
  p_fecha_fin date DEFAULT NULL,
  p_vencimiento_at timestamptz DEFAULT NULL,
  p_aplica_todas_sedes boolean DEFAULT true,
  p_sede text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_inicio date;
  v_hora time without time zone;
  v_at timestamptz;
  v_rec text;
  v_todas boolean;
  v_sede text;
  sede_nom text;
  sedes text[];
BEGIN
  IF NOT public.has_permission('crear_todo') THEN
    RAISE EXCEPTION 'Sin permiso para crear tareas';
  END IF;
  IF p_titulo IS NULL OR btrim(p_titulo) = '' THEN
    RAISE EXCEPTION 'El título es obligatorio';
  END IF;
  IF p_responsable_tipo = 'usuario' AND p_responsable_user_id IS NULL THEN
    RAISE EXCEPTION 'Debe indicar el usuario responsable';
  END IF;
  IF p_responsable_tipo = 'rol' AND (p_responsable_role IS NULL OR btrim(p_responsable_role) = '') THEN
    RAISE EXCEPTION 'Debe indicar el perfil responsable';
  END IF;

  v_rec := COALESCE(p_recurrencia, 'ninguna');
  v_inicio := COALESCE(p_fecha_inicio, public.fecha_hoy_argentina());
  v_hora := COALESCE(p_hora_vencimiento, time '23:59');
  v_todas := COALESCE(p_aplica_todas_sedes, true);
  v_sede := NULLIF(btrim(COALESCE(p_sede, '')), '');

  IF v_todas THEN
    v_sede := NULL;
  END IF;
  -- empresa: v_todas=false y v_sede=NULL → una sola instancia
  -- una sede: v_todas=false y v_sede NOT NULL

  IF v_rec <> 'ninguna' THEN
    IF p_fecha_fin IS NULL THEN
      RAISE EXCEPTION 'En tareas recurrentes debés indicar hasta qué fecha se replica';
    END IF;
    IF p_fecha_fin < v_inicio THEN
      RAISE EXCEPTION 'La fecha hasta no puede ser anterior al inicio';
    END IF;
    IF p_fecha_fin > v_inicio + 366 THEN
      RAISE EXCEPTION 'El rango de réplica no puede superar 366 días';
    END IF;
  END IF;

  INSERT INTO public.todo_tarea (
    titulo, descripcion, prioridad,
    responsable_tipo, responsable_user_id, responsable_role,
    recurrencia, hora_vencimiento, dia_semana, dia_mes,
    fecha_inicio, fecha_fin, activa, creado_por,
    aplica_todas_sedes, sede
  ) VALUES (
    btrim(p_titulo), NULLIF(btrim(COALESCE(p_descripcion, '')), ''), COALESCE(p_prioridad, 2),
    p_responsable_tipo,
    CASE WHEN p_responsable_tipo = 'usuario' THEN p_responsable_user_id ELSE NULL END,
    CASE WHEN p_responsable_tipo = 'rol' THEN p_responsable_role ELSE NULL END,
    v_rec,
    v_hora,
    CASE WHEN v_rec = 'semanal' THEN p_dia_semana ELSE NULL END,
    CASE WHEN v_rec IN ('mensual', 'bimestral', 'trimestral', 'anual') THEN p_dia_mes ELSE NULL END,
    v_inicio,
    CASE WHEN v_rec = 'ninguna' THEN NULL ELSE p_fecha_fin END,
    true,
    auth.uid(),
    v_todas,
    v_sede
  )
  RETURNING id INTO v_id;

  IF v_rec = 'ninguna' THEN
    v_at := COALESCE(p_vencimiento_at, public.todo_ts_argentina(v_inicio, v_hora));
    SELECT public.todo_sedes_para_tarea(t) INTO sedes
    FROM public.todo_tarea t WHERE t.id = v_id;
    IF sedes IS NULL OR coalesce(array_length(sedes, 1), 0) = 0 THEN
      sedes := ARRAY[NULL]::text[];
    END IF;
    FOREACH sede_nom IN ARRAY sedes LOOP
      INSERT INTO public.todo_instancia (
        tarea_id, titulo, descripcion, prioridad,
        responsable_tipo, responsable_user_id, responsable_role,
        vencimiento_at, estado, sede
      )
      SELECT
        v_id, t.titulo, t.descripcion, t.prioridad,
        t.responsable_tipo, t.responsable_user_id, t.responsable_role,
        v_at, 'pendiente', sede_nom
      FROM public.todo_tarea t WHERE t.id = v_id;
    END LOOP;
  ELSE
    PERFORM public.todo_generar_instancias_tarea_interno(v_id, NULL);
  END IF;

  RETURN v_id;
END;
$$;

-- Eliminar: evita que todo_generar_instancias_* vuelva a crear la fila.
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
  v_rec text;
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

  IF COALESCE(p_eliminar_plantilla, false) AND tid IS NOT NULL THEN
    UPDATE public.todo_tarea SET activa = false, updated_at = now() WHERE id = tid;
    DELETE FROM public.todo_instancia
    WHERE tarea_id = tid
      AND estado IN ('pendiente', 'en_curso');
    -- Por si la actual no estaba en esos estados
    DELETE FROM public.todo_instancia WHERE id = p_instancia_id;
    RETURN;
  END IF;

  -- Solo esta ocurrencia: marcar cancelada (el generador no recrea si ya existe la fila)
  UPDATE public.todo_instancia
  SET estado = 'cancelada', updated_at = now()
  WHERE id = p_instancia_id;

  IF tid IS NOT NULL THEN
    SELECT recurrencia INTO v_rec FROM public.todo_tarea WHERE id = tid;
    -- Tarea única: desactivar plantilla para que no se regenere
    IF COALESCE(v_rec, 'ninguna') = 'ninguna' THEN
      UPDATE public.todo_tarea SET activa = false, updated_at = now() WHERE id = tid;
    END IF;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_crear_tarea(text, text, smallint, text, uuid, text, text, time without time zone, smallint, smallint, date, date, timestamptz, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_eliminar_instancia(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_sedes_para_tarea(public.todo_tarea) TO authenticated;

-- Por defecto la bandeja no lista canceladas (eliminadas); sí si se filtra estado=cancelada.
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
  vencimiento_at timestamptz,
  estado text,
  estado_efectivo text,
  recurrencia text,
  sede text,
  completada_at timestamptz,
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
      ELSE COALESCE(up.email, i.responsable_user_id::text)
    END AS responsable_label,
    i.vencimiento_at,
    i.estado,
    CASE
      WHEN i.estado IN ('pendiente', 'en_curso') AND i.vencimiento_at < now() THEN 'vencida'
      ELSE i.estado
    END AS estado_efectivo,
    COALESCE(t.recurrencia, 'ninguna') AS recurrencia,
    i.sede,
    i.completada_at,
    i.created_at
  FROM public.todo_instancia i
  LEFT JOIN public.todo_tarea t ON t.id = i.tarea_id
  LEFT JOIN public.app_role ar ON ar.role = i.responsable_role
  LEFT JOIN public.user_profiles up ON up.id = i.responsable_user_id
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
      OR (
        p_estado = 'vencida'
        AND i.estado IN ('pendiente', 'en_curso')
        AND i.vencimiento_at < now()
      )
      OR (p_estado IS NOT NULL AND p_estado <> 'vencida' AND i.estado = p_estado)
    )
    AND (
      p_ventana IS NULL OR p_ventana = 'todas'
      OR (p_ventana = 'hoy' AND i.vencimiento_at >= desde AND i.vencimiento_at <= hasta)
      OR (p_ventana = 'semana' AND i.vencimiento_at >= desde AND i.vencimiento_at <= hasta)
      OR (
        p_ventana = 'vencidas'
        AND i.estado IN ('pendiente', 'en_curso')
        AND i.vencimiento_at < now()
      )
    )
  ORDER BY
    CASE
      WHEN i.estado IN ('pendiente', 'en_curso') AND i.vencimiento_at < now() THEN 0
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
