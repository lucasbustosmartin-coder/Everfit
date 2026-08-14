-- Primer vencimiento de la serie: ancla de la recurrencia (diario/semanal/mensual/…).
-- Prerrequisito: sql/supabase_todo_empresa_y_eliminar.sql + recurrencias bimestral/trimestral.

CREATE OR REPLACE FUNCTION public.todo_next_dates(
  p_recurrencia text,
  p_fecha_inicio date,
  p_fecha_fin date,
  p_dia_semana smallint,
  p_dia_mes smallint,
  p_hasta date
)
RETURNS SETOF date
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
DECLARE
  d date;
  last_day date;
  candidate date;
  step_months int;
  ancla date;
  usar_dia_mes boolean;
BEGIN
  ancla := COALESCE(p_fecha_inicio, public.fecha_hoy_argentina());
  d := ancla;

  IF p_recurrencia = 'ninguna' THEN
    RETURN NEXT d;
    RETURN;
  END IF;

  last_day := LEAST(COALESCE(p_fecha_fin, p_hasta), p_hasta);
  IF last_day IS NULL OR d > last_day THEN
    RETURN;
  END IF;

  IF p_recurrencia = 'diaria' THEN
    WHILE d <= last_day LOOP
      RETURN NEXT d;
      d := d + 1;
    END LOOP;
    RETURN;
  END IF;

  IF p_recurrencia = 'semanal' THEN
    IF p_dia_semana IS NOT NULL AND EXTRACT(ISODOW FROM d)::int <> p_dia_semana THEN
      WHILE EXTRACT(ISODOW FROM d)::int <> p_dia_semana LOOP
        d := d + 1;
        IF d > last_day THEN RETURN; END IF;
      END LOOP;
    END IF;
    WHILE d <= last_day LOOP
      RETURN NEXT d;
      d := d + 7;
    END LOOP;
    RETURN;
  END IF;

  IF p_recurrencia IN ('mensual', 'bimestral', 'trimestral', 'anual') THEN
    step_months := CASE p_recurrencia
      WHEN 'bimestral' THEN 2
      WHEN 'trimestral' THEN 3
      WHEN 'anual' THEN 12
      ELSE 1
    END;
    usar_dia_mes := p_dia_mes IS NOT NULL AND EXTRACT(DAY FROM ancla)::int <> p_dia_mes::int;

    IF NOT usar_dia_mes THEN
      WHILE d <= last_day LOOP
        RETURN NEXT d;
        d := (d + pg_catalog.make_interval(months => step_months))::date;
      END LOOP;
      RETURN;
    END IF;

    -- Plantillas viejas: día del mes distinto al ancla
    d := date_trunc('month', ancla)::date;
    WHILE d <= last_day LOOP
      candidate := pg_catalog.make_date(
        EXTRACT(YEAR FROM d)::int,
        EXTRACT(MONTH FROM d)::int,
        LEAST(
          p_dia_mes::int,
          EXTRACT(DAY FROM (date_trunc('month', d) + interval '1 month' - interval '1 day'))::int
        )
      );
      IF candidate >= ancla AND candidate <= last_day THEN
        RETURN NEXT candidate;
      END IF;
      d := (date_trunc('month', d) + pg_catalog.make_interval(months => step_months))::date;
    END LOOP;
    RETURN;
  END IF;
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
  v_dow smallint;
  v_dom smallint;
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
  v_dow := EXTRACT(ISODOW FROM v_inicio)::smallint;
  v_dom := EXTRACT(DAY FROM v_inicio)::smallint;

  IF v_todas THEN
    v_sede := NULL;
  END IF;

  IF v_rec <> 'ninguna' THEN
    IF p_fecha_fin IS NULL THEN
      RAISE EXCEPTION 'En tareas recurrentes debés indicar hasta qué fecha se replica';
    END IF;
    IF p_fecha_fin < v_inicio THEN
      RAISE EXCEPTION 'La fecha hasta no puede ser anterior al primer vencimiento';
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
    CASE WHEN v_rec = 'semanal' THEN COALESCE(p_dia_semana, v_dow) ELSE NULL END,
    CASE WHEN v_rec IN ('mensual', 'bimestral', 'trimestral', 'anual') THEN COALESCE(p_dia_mes, v_dom) ELSE NULL END,
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

GRANT EXECUTE ON FUNCTION public.todo_next_dates(text, date, date, smallint, smallint, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_crear_tarea(text, text, smallint, text, uuid, text, text, time without time zone, smallint, smallint, date, date, timestamptz, boolean, text) TO authenticated;
