-- =============================================================================
-- Everfit – Módulo To-Do (tareas / bandeja)
-- Prerrequisito: sql/helpers_fecha_argentina.sql, sql/supabase_seguridad.sql
-- =============================================================================

-- ---------- 1. Helper fecha Argentina ----------
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

-- ---------- 2. Roles nuevos ----------
INSERT INTO public.app_role (role, label) VALUES
  ('recepcionista', 'Recepcionista'),
  ('profesor', 'Profesor')
ON CONFLICT (role) DO UPDATE SET label = EXCLUDED.label;

-- ---------- 3. Permisos To-Do ----------
INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_todo', 'Ver menú To-Do y bandeja de tareas atribuibles'),
  ('crear_todo', 'Crear y administrar tareas del To-Do'),
  ('completar_todo', 'Cambiar estado de tareas del To-Do (pendiente, en curso, hecha, cancelada)')
ON CONFLICT (permission) DO UPDATE SET description = EXCLUDED.description;

-- Defaults: ver/completar para todos los roles; crear solo Admin y Encargado
INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'ver_todo'),
  ('admin', 'crear_todo'),
  ('admin', 'completar_todo'),
  ('encargado', 'ver_todo'),
  ('encargado', 'crear_todo'),
  ('encargado', 'completar_todo'),
  ('visor', 'ver_todo'),
  ('visor', 'completar_todo'),
  ('recepcionista', 'ver_todo'),
  ('recepcionista', 'completar_todo'),
  ('recepcionista', 'ver_asistencia'),
  ('profesor', 'ver_todo'),
  ('profesor', 'completar_todo'),
  ('profesor', 'ver_asistencia')
ON CONFLICT (role, permission) DO NOTHING;

-- Orden de roles en Seguridad (incluye nuevos)
CREATE OR REPLACE FUNCTION public.get_roles_permissions_for_admin()
RETURNS TABLE (role text, role_label text, permission text, perm_description text, granted boolean)
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
  SELECT r.role, r.label, p.permission, COALESCE(p.description, ''), (rp.role IS NOT NULL)
  FROM public.app_role r
  CROSS JOIN public.app_permission p
  LEFT JOIN public.app_role_permission rp ON rp.role = r.role AND rp.permission = p.permission
  ORDER BY (
    CASE r.role
      WHEN 'admin' THEN 1
      WHEN 'encargado' THEN 2
      WHEN 'recepcionista' THEN 3
      WHEN 'profesor' THEN 4
      WHEN 'visor' THEN 5
      ELSE 6
    END
  ), p.permission;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_roles_permissions_for_admin() TO authenticated;

-- ---------- 4. Tablas ----------
CREATE TABLE IF NOT EXISTS public.todo_tarea (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo text NOT NULL,
  descripcion text,
  prioridad smallint NOT NULL DEFAULT 2 CHECK (prioridad BETWEEN 1 AND 3),
  responsable_tipo text NOT NULL CHECK (responsable_tipo IN ('usuario', 'rol')),
  responsable_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  responsable_role text REFERENCES public.app_role(role),
  recurrencia text NOT NULL DEFAULT 'ninguna'
    CHECK (recurrencia IN ('ninguna', 'diaria', 'semanal', 'mensual', 'anual', 'hora_fija')),
  hora_vencimiento time without time zone,
  dia_semana smallint CHECK (dia_semana IS NULL OR (dia_semana BETWEEN 1 AND 7)),
  dia_mes smallint CHECK (dia_mes IS NULL OR (dia_mes BETWEEN 1 AND 31)),
  fecha_inicio date NOT NULL DEFAULT public.fecha_hoy_argentina(),
  fecha_fin date,
  activa boolean NOT NULL DEFAULT true,
  creado_por uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT todo_tarea_responsable_chk CHECK (
    (responsable_tipo = 'usuario' AND responsable_user_id IS NOT NULL)
    OR (responsable_tipo = 'rol' AND responsable_role IS NOT NULL)
  ),
  CONSTRAINT todo_tarea_recurrencia_params_chk CHECK (
    (recurrencia = 'ninguna')
    OR (recurrencia = 'diaria')
    OR (recurrencia = 'hora_fija' AND hora_vencimiento IS NOT NULL)
    OR (recurrencia = 'semanal' AND dia_semana IS NOT NULL)
    OR (recurrencia = 'mensual' AND dia_mes IS NOT NULL)
    OR (recurrencia = 'anual' AND dia_mes IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_todo_tarea_activa ON public.todo_tarea (activa);
CREATE INDEX IF NOT EXISTS idx_todo_tarea_responsable_user ON public.todo_tarea (responsable_user_id);
CREATE INDEX IF NOT EXISTS idx_todo_tarea_responsable_role ON public.todo_tarea (responsable_role);

COMMENT ON TABLE public.todo_tarea IS 'Plantilla / definición de tarea To-Do (incluye recurrencia).';
COMMENT ON COLUMN public.todo_tarea.prioridad IS '1=alta, 2=media, 3=baja';
COMMENT ON COLUMN public.todo_tarea.dia_semana IS 'ISO: 1=lunes … 7=domingo';

CREATE TABLE IF NOT EXISTS public.todo_instancia (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tarea_id uuid REFERENCES public.todo_tarea(id) ON DELETE CASCADE,
  titulo text NOT NULL,
  descripcion text,
  prioridad smallint NOT NULL DEFAULT 2 CHECK (prioridad BETWEEN 1 AND 3),
  responsable_tipo text NOT NULL CHECK (responsable_tipo IN ('usuario', 'rol')),
  responsable_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  responsable_role text REFERENCES public.app_role(role),
  vencimiento_at timestamptz NOT NULL,
  estado text NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'en_curso', 'hecha', 'cancelada')),
  completada_at timestamptz,
  completada_por uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT todo_instancia_responsable_chk CHECK (
    (responsable_tipo = 'usuario' AND responsable_user_id IS NOT NULL)
    OR (responsable_tipo = 'rol' AND responsable_role IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_todo_instancia_tarea_venc
  ON public.todo_instancia (tarea_id, vencimiento_at)
  WHERE tarea_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_todo_instancia_estado ON public.todo_instancia (estado);
CREATE INDEX IF NOT EXISTS idx_todo_instancia_vencimiento ON public.todo_instancia (vencimiento_at);
CREATE INDEX IF NOT EXISTS idx_todo_instancia_resp_user ON public.todo_instancia (responsable_user_id);
CREATE INDEX IF NOT EXISTS idx_todo_instancia_resp_role ON public.todo_instancia (responsable_role);

COMMENT ON TABLE public.todo_instancia IS 'Ocurrencias de tareas To-Do visibles en la bandeja.';

-- ---------- 5. Helpers de acceso ----------
CREATE OR REPLACE FUNCTION public.todo_puede_ver_instancia(i public.todo_instancia)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    public.has_permission('ver_todo')
    AND (
      public.has_permission('crear_todo')
      OR (i.responsable_tipo = 'usuario' AND i.responsable_user_id = auth.uid())
      OR (i.responsable_tipo = 'rol' AND i.responsable_role = public.get_my_role())
    );
$$;

CREATE OR REPLACE FUNCTION public.todo_puede_operar_instancia(i public.todo_instancia)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    public.has_permission('completar_todo')
    AND (
      public.has_permission('crear_todo')
      OR (i.responsable_tipo = 'usuario' AND i.responsable_user_id = auth.uid())
      OR (i.responsable_tipo = 'rol' AND i.responsable_role = public.get_my_role())
    );
$$;

-- ---------- 6. RLS ----------
ALTER TABLE public.todo_tarea ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.todo_instancia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS todo_tarea_select ON public.todo_tarea;
CREATE POLICY todo_tarea_select ON public.todo_tarea
  FOR SELECT TO authenticated
  USING (
    public.has_permission('ver_todo')
    AND (
      public.has_permission('crear_todo')
      OR (responsable_tipo = 'usuario' AND responsable_user_id = auth.uid())
      OR (responsable_tipo = 'rol' AND responsable_role = public.get_my_role())
      OR creado_por = auth.uid()
    )
  );

DROP POLICY IF EXISTS todo_tarea_insert ON public.todo_tarea;
CREATE POLICY todo_tarea_insert ON public.todo_tarea
  FOR INSERT TO authenticated
  WITH CHECK (public.has_permission('crear_todo') AND creado_por = auth.uid());

DROP POLICY IF EXISTS todo_tarea_update ON public.todo_tarea;
CREATE POLICY todo_tarea_update ON public.todo_tarea
  FOR UPDATE TO authenticated
  USING (public.has_permission('crear_todo'))
  WITH CHECK (public.has_permission('crear_todo'));

DROP POLICY IF EXISTS todo_tarea_delete ON public.todo_tarea;
CREATE POLICY todo_tarea_delete ON public.todo_tarea
  FOR DELETE TO authenticated
  USING (public.has_permission('crear_todo'));

DROP POLICY IF EXISTS todo_instancia_select ON public.todo_instancia;
CREATE POLICY todo_instancia_select ON public.todo_instancia
  FOR SELECT TO authenticated
  USING (public.todo_puede_ver_instancia(todo_instancia));

DROP POLICY IF EXISTS todo_instancia_insert ON public.todo_instancia;
CREATE POLICY todo_instancia_insert ON public.todo_instancia
  FOR INSERT TO authenticated
  WITH CHECK (public.has_permission('crear_todo'));

DROP POLICY IF EXISTS todo_instancia_update ON public.todo_instancia;
CREATE POLICY todo_instancia_update ON public.todo_instancia
  FOR UPDATE TO authenticated
  USING (public.todo_puede_operar_instancia(todo_instancia))
  WITH CHECK (public.todo_puede_operar_instancia(todo_instancia));

DROP POLICY IF EXISTS todo_instancia_delete ON public.todo_instancia;
CREATE POLICY todo_instancia_delete ON public.todo_instancia
  FOR DELETE TO authenticated
  USING (public.has_permission('crear_todo'));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.todo_tarea TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.todo_instancia TO authenticated;

-- ---------- 7. Cálculo de vencimientos (Argentina) ----------
CREATE OR REPLACE FUNCTION public.todo_ts_argentina(p_fecha date, p_hora time without time zone)
RETURNS timestamptz
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT ((p_fecha::text || ' ' || COALESCE(p_hora, time '23:59')::text)::timestamp
    AT TIME ZONE 'America/Argentina/Buenos_Aires');
$$;

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
BEGIN
  IF p_recurrencia = 'ninguna' THEN
    RETURN NEXT COALESCE(p_fecha_inicio, public.fecha_hoy_argentina());
    RETURN;
  END IF;

  d := COALESCE(p_fecha_inicio, public.fecha_hoy_argentina());
  last_day := LEAST(COALESCE(p_fecha_fin, p_hasta), p_hasta);

  IF p_recurrencia = 'diaria' OR p_recurrencia = 'hora_fija' THEN
    WHILE d <= last_day LOOP
      RETURN NEXT d;
      d := d + 1;
    END LOOP;
    RETURN;
  END IF;

  IF p_recurrencia = 'semanal' THEN
    -- Avanzar al primer día_semana ISO >= d
    WHILE EXTRACT(ISODOW FROM d)::int <> p_dia_semana LOOP
      d := d + 1;
      IF d > last_day THEN RETURN; END IF;
    END LOOP;
    WHILE d <= last_day LOOP
      RETURN NEXT d;
      d := d + 7;
    END LOOP;
    RETURN;
  END IF;

  IF p_recurrencia = 'mensual' THEN
    WHILE d <= last_day LOOP
      candidate := make_date(
        EXTRACT(YEAR FROM d)::int,
        EXTRACT(MONTH FROM d)::int,
        LEAST(p_dia_mes::int, EXTRACT(DAY FROM (date_trunc('month', d) + interval '1 month - 1 day'))::int)
      );
      IF candidate < COALESCE(p_fecha_inicio, candidate) THEN
        d := (date_trunc('month', d) + interval '1 month')::date;
        CONTINUE;
      END IF;
      IF candidate >= COALESCE(p_fecha_inicio, candidate) AND candidate <= last_day THEN
        RETURN NEXT candidate;
      END IF;
      d := (date_trunc('month', d) + interval '1 month')::date;
    END LOOP;
    RETURN;
  END IF;

  IF p_recurrencia = 'anual' THEN
    WHILE d <= last_day LOOP
      BEGIN
        candidate := make_date(EXTRACT(YEAR FROM d)::int, 1, LEAST(p_dia_mes::int, 28));
        -- Anual: día del año = dia_mes en mes 1 por simplicidad si no hay mes; usamos mes de fecha_inicio
        candidate := make_date(
          EXTRACT(YEAR FROM d)::int,
          EXTRACT(MONTH FROM COALESCE(p_fecha_inicio, d))::int,
          LEAST(
            p_dia_mes::int,
            EXTRACT(DAY FROM (
              date_trunc('month', make_date(EXTRACT(YEAR FROM d)::int, EXTRACT(MONTH FROM COALESCE(p_fecha_inicio, d))::int, 1))
              + interval '1 month - 1 day'
            ))::int
          )
        );
      EXCEPTION WHEN others THEN
        candidate := NULL;
      END;
      IF candidate IS NOT NULL AND candidate >= COALESCE(p_fecha_inicio, candidate) AND candidate <= last_day THEN
        RETURN NEXT candidate;
      END IF;
      d := make_date(EXTRACT(YEAR FROM d)::int + 1, 1, 1);
    END LOOP;
    RETURN;
  END IF;
END;
$$;

-- ---------- 8. Generar instancias de una plantilla ----------
CREATE OR REPLACE FUNCTION public.todo_generar_instancias_tarea(p_tarea_id uuid, p_dias_ventana int DEFAULT 45)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  t public.todo_tarea%ROWTYPE;
  d date;
  v_at timestamptz;
  inserted int := 0;
  hasta date;
  hora time without time zone;
BEGIN
  IF NOT public.has_permission('crear_todo') AND auth.uid() IS DISTINCT FROM NULL THEN
    -- Permitir también llamado interno; si no hay permiso y no es service, salir
    IF NOT public.has_permission('crear_todo') THEN
      RAISE EXCEPTION 'Sin permiso para generar instancias';
    END IF;
  END IF;

  SELECT * INTO t FROM public.todo_tarea WHERE id = p_tarea_id;
  IF NOT FOUND OR NOT t.activa THEN
    RETURN 0;
  END IF;

  hasta := public.fecha_hoy_argentina() + GREATEST(COALESCE(p_dias_ventana, 45), 1);
  hora := COALESCE(t.hora_vencimiento, time '23:59');

  FOR d IN
    SELECT * FROM public.todo_next_dates(
      t.recurrencia, t.fecha_inicio, t.fecha_fin, t.dia_semana, t.dia_mes, hasta
    )
  LOOP
    v_at := public.todo_ts_argentina(d, hora);
    INSERT INTO public.todo_instancia (
      tarea_id, titulo, descripcion, prioridad,
      responsable_tipo, responsable_user_id, responsable_role,
      vencimiento_at, estado
    )
    VALUES (
      t.id, t.titulo, t.descripcion, t.prioridad,
      t.responsable_tipo, t.responsable_user_id, t.responsable_role,
      v_at, 'pendiente'
    )
    ON CONFLICT DO NOTHING;
    IF FOUND THEN
      inserted := inserted + 1;
    END IF;
  END LOOP;

  -- UNIQUE parcial: ON CONFLICT necesita constraint name; usar anti-join más seguro
  RETURN inserted;
END;
$$;

-- Reescribir generación con anti-join (ON CONFLICT con índice parcial es frágil sin nombre)
CREATE OR REPLACE FUNCTION public.todo_generar_instancias_tarea(p_tarea_id uuid, p_dias_ventana int DEFAULT 45)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  t public.todo_tarea%ROWTYPE;
  d date;
  v_at timestamptz;
  inserted int := 0;
  hasta date;
  hora time without time zone;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.has_permission('crear_todo') THEN
    RAISE EXCEPTION 'Sin permiso para generar instancias';
  END IF;

  SELECT * INTO t FROM public.todo_tarea WHERE id = p_tarea_id;
  IF NOT FOUND OR NOT t.activa THEN
    RETURN 0;
  END IF;

  hasta := public.fecha_hoy_argentina() + GREATEST(COALESCE(p_dias_ventana, 45), 1);
  hora := COALESCE(t.hora_vencimiento, time '23:59');

  FOR d IN
    SELECT x FROM public.todo_next_dates(
      t.recurrencia, t.fecha_inicio, t.fecha_fin, t.dia_semana, t.dia_mes, hasta
    ) AS x
  LOOP
    v_at := public.todo_ts_argentina(d, hora);
    IF NOT EXISTS (
      SELECT 1 FROM public.todo_instancia i
      WHERE i.tarea_id = t.id AND i.vencimiento_at = v_at
    ) THEN
      INSERT INTO public.todo_instancia (
        tarea_id, titulo, descripcion, prioridad,
        responsable_tipo, responsable_user_id, responsable_role,
        vencimiento_at, estado
      ) VALUES (
        t.id, t.titulo, t.descripcion, t.prioridad,
        t.responsable_tipo, t.responsable_user_id, t.responsable_role,
        v_at, 'pendiente'
      );
      inserted := inserted + 1;
    END IF;
  END LOOP;

  RETURN inserted;
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_generar_instancias_todas(p_dias_ventana int DEFAULT 45)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  tid uuid;
  total int := 0;
  n int;
BEGIN
  IF NOT public.has_permission('crear_todo') AND NOT public.has_permission('ver_todo') THEN
    RAISE EXCEPTION 'Sin permiso';
  END IF;
  FOR tid IN SELECT id FROM public.todo_tarea WHERE activa = true LOOP
    -- Bypass permiso crear en generación masiva para usuarios con ver_todo (materializar al abrir bandeja)
    n := public.todo_generar_instancias_tarea_interno(tid, p_dias_ventana);
    total := total + n;
  END LOOP;
  RETURN total;
END;
$$;

CREATE OR REPLACE FUNCTION public.todo_generar_instancias_tarea_interno(p_tarea_id uuid, p_dias_ventana int DEFAULT 45)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  t public.todo_tarea%ROWTYPE;
  d date;
  v_at timestamptz;
  inserted int := 0;
  hasta date;
  hora time without time zone;
BEGIN
  SELECT * INTO t FROM public.todo_tarea WHERE id = p_tarea_id;
  IF NOT FOUND OR NOT t.activa THEN
    RETURN 0;
  END IF;

  hasta := public.fecha_hoy_argentina() + GREATEST(COALESCE(p_dias_ventana, 45), 1);
  hora := COALESCE(t.hora_vencimiento, time '23:59');

  FOR d IN
    SELECT x FROM public.todo_next_dates(
      t.recurrencia, t.fecha_inicio, t.fecha_fin, t.dia_semana, t.dia_mes, hasta
    ) AS x
  LOOP
    v_at := public.todo_ts_argentina(d, hora);
    IF NOT EXISTS (
      SELECT 1 FROM public.todo_instancia i
      WHERE i.tarea_id = t.id AND i.vencimiento_at = v_at
    ) THEN
      INSERT INTO public.todo_instancia (
        tarea_id, titulo, descripcion, prioridad,
        responsable_tipo, responsable_user_id, responsable_role,
        vencimiento_at, estado
      ) VALUES (
        t.id, t.titulo, t.descripcion, t.prioridad,
        t.responsable_tipo, t.responsable_user_id, t.responsable_role,
        v_at, 'pendiente'
      );
      inserted := inserted + 1;
    END IF;
  END LOOP;

  RETURN inserted;
END;
$$;

-- Regenerar todo_generar_instancias_todas usando interno
CREATE OR REPLACE FUNCTION public.todo_generar_instancias_todas(p_dias_ventana int DEFAULT 45)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  tid uuid;
  total int := 0;
  n int;
BEGIN
  IF NOT public.has_permission('ver_todo') THEN
    RAISE EXCEPTION 'Sin permiso';
  END IF;
  FOR tid IN SELECT id FROM public.todo_tarea WHERE activa = true LOOP
    n := public.todo_generar_instancias_tarea_interno(tid, p_dias_ventana);
    total := total + n;
  END LOOP;
  RETURN total;
END;
$$;

-- ---------- 9. RPC crear tarea ----------
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
  p_vencimiento_at timestamptz DEFAULT NULL
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

  v_inicio := COALESCE(p_fecha_inicio, public.fecha_hoy_argentina());
  v_hora := COALESCE(p_hora_vencimiento, time '23:59');

  INSERT INTO public.todo_tarea (
    titulo, descripcion, prioridad,
    responsable_tipo, responsable_user_id, responsable_role,
    recurrencia, hora_vencimiento, dia_semana, dia_mes,
    fecha_inicio, fecha_fin, activa, creado_por
  ) VALUES (
    btrim(p_titulo), NULLIF(btrim(COALESCE(p_descripcion, '')), ''), COALESCE(p_prioridad, 2),
    p_responsable_tipo,
    CASE WHEN p_responsable_tipo = 'usuario' THEN p_responsable_user_id ELSE NULL END,
    CASE WHEN p_responsable_tipo = 'rol' THEN p_responsable_role ELSE NULL END,
    COALESCE(p_recurrencia, 'ninguna'),
    CASE
      WHEN COALESCE(p_recurrencia, 'ninguna') IN ('diaria', 'hora_fija', 'semanal', 'mensual', 'anual') THEN v_hora
      WHEN p_hora_vencimiento IS NOT NULL THEN p_hora_vencimiento
      ELSE NULL
    END,
    CASE WHEN COALESCE(p_recurrencia, 'ninguna') = 'semanal' THEN p_dia_semana ELSE NULL END,
    CASE WHEN COALESCE(p_recurrencia, 'ninguna') IN ('mensual', 'anual') THEN p_dia_mes ELSE NULL END,
    v_inicio,
    p_fecha_fin,
    true,
    auth.uid()
  )
  RETURNING id INTO v_id;

  IF COALESCE(p_recurrencia, 'ninguna') = 'ninguna' THEN
    v_at := COALESCE(p_vencimiento_at, public.todo_ts_argentina(v_inicio, v_hora));
    INSERT INTO public.todo_instancia (
      tarea_id, titulo, descripcion, prioridad,
      responsable_tipo, responsable_user_id, responsable_role,
      vencimiento_at, estado
    )
    SELECT
      v_id, t.titulo, t.descripcion, t.prioridad,
      t.responsable_tipo, t.responsable_user_id, t.responsable_role,
      v_at, 'pendiente'
    FROM public.todo_tarea t WHERE t.id = v_id;
  ELSE
    PERFORM public.todo_generar_instancias_tarea_interno(v_id, 45);
  END IF;

  RETURN v_id;
END;
$$;

-- ---------- 10. RPC bandeja ----------
CREATE OR REPLACE FUNCTION public.todo_list_inbox(
  p_estado text DEFAULT NULL,
  p_prioridad smallint DEFAULT NULL,
  p_ventana text DEFAULT 'todas'
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
BEGIN
  IF NOT public.has_permission('ver_todo') THEN
    RETURN;
  END IF;

  my_role := public.get_my_role();
  can_all := public.has_permission('crear_todo');
  hoy := public.fecha_hoy_argentina();

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

  -- Materialización: llamar todo_generar_instancias_todas desde el cliente (VOLATILE).

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
    AND (p_prioridad IS NULL OR i.prioridad = p_prioridad)
    AND (
      p_estado IS NULL
      OR (
        p_estado = 'vencida'
        AND i.estado IN ('pendiente', 'en_curso')
        AND i.vencimiento_at < now()
      )
      OR (p_estado <> 'vencida' AND i.estado = p_estado)
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
    i.vencimiento_at ASC,
    i.prioridad ASC;
END;
$$;

-- ---------- 11. Cambiar estado ----------
CREATE OR REPLACE FUNCTION public.todo_cambiar_estado(p_instancia_id uuid, p_estado text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  i public.todo_instancia%ROWTYPE;
BEGIN
  IF p_estado NOT IN ('pendiente', 'en_curso', 'hecha', 'cancelada') THEN
    RAISE EXCEPTION 'Estado inválido';
  END IF;

  SELECT * INTO i FROM public.todo_instancia WHERE id = p_instancia_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tarea no encontrada';
  END IF;

  IF NOT public.todo_puede_operar_instancia(i) THEN
    RAISE EXCEPTION 'Sin permiso para cambiar el estado';
  END IF;

  UPDATE public.todo_instancia
  SET
    estado = p_estado,
    completada_at = CASE WHEN p_estado = 'hecha' THEN now() ELSE NULL END,
    completada_por = CASE WHEN p_estado = 'hecha' THEN auth.uid() ELSE NULL END,
    updated_at = now()
  WHERE id = p_instancia_id;
END;
$$;

-- ---------- 12. Catálogos para el formulario ----------
CREATE OR REPLACE FUNCTION public.todo_list_usuarios()
RETURNS TABLE (user_id uuid, email text, role text, role_label text)
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
  IF NOT public.has_permission('crear_todo') THEN
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

CREATE OR REPLACE FUNCTION public.todo_resumen_bandeja()
RETURNS TABLE (
  pendientes bigint,
  en_curso bigint,
  vencidas bigint,
  hechas_hoy bigint
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
BEGIN
  IF NOT public.has_permission('ver_todo') THEN
    RETURN QUERY SELECT 0::bigint, 0::bigint, 0::bigint, 0::bigint;
    RETURN;
  END IF;

  my_role := public.get_my_role();
  can_all := public.has_permission('crear_todo');
  hoy := public.fecha_hoy_argentina();
  desde := public.todo_ts_argentina(hoy, time '00:00');
  hasta := public.todo_ts_argentina(hoy, time '23:59:59');

  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE i.estado = 'pendiente' AND i.vencimiento_at >= now())::bigint,
    COUNT(*) FILTER (WHERE i.estado = 'en_curso' AND i.vencimiento_at >= now())::bigint,
    COUNT(*) FILTER (WHERE i.estado IN ('pendiente', 'en_curso') AND i.vencimiento_at < now())::bigint,
    COUNT(*) FILTER (WHERE i.estado = 'hecha' AND i.completada_at >= desde AND i.completada_at <= hasta)::bigint
  FROM public.todo_instancia i
  WHERE
    can_all
    OR (i.responsable_tipo = 'usuario' AND i.responsable_user_id = auth.uid())
    OR (i.responsable_tipo = 'rol' AND i.responsable_role = my_role);
END;
$$;

GRANT EXECUTE ON FUNCTION public.todo_puede_ver_instancia(public.todo_instancia) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_puede_operar_instancia(public.todo_instancia) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_ts_argentina(date, time without time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_next_dates(text, date, date, smallint, smallint, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_generar_instancias_tarea(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_generar_instancias_tarea_interno(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_generar_instancias_todas(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_crear_tarea(text, text, smallint, text, uuid, text, text, time without time zone, smallint, smallint, date, date, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_list_inbox(text, smallint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_cambiar_estado(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_list_usuarios() TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_list_roles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.todo_resumen_bandeja() TO authenticated;
