-- Recurrencias To-Do: quitar hora_fija; agregar bimestral y trimestral.
-- Prerrequisito: supabase_todo.sql / supabase_todo_sede_y_fecha_fin.sql

UPDATE public.todo_tarea SET recurrencia = 'diaria' WHERE recurrencia = 'hora_fija';

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    WHERE t.relname = 'todo_tarea' AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) ILIKE '%hora_fija%'
  LOOP
    EXECUTE format('ALTER TABLE public.todo_tarea DROP CONSTRAINT IF EXISTS %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE public.todo_tarea DROP CONSTRAINT IF EXISTS todo_tarea_recurrencia_check;
ALTER TABLE public.todo_tarea DROP CONSTRAINT IF EXISTS todo_tarea_recurrencia_params_chk;

ALTER TABLE public.todo_tarea
  ADD CONSTRAINT todo_tarea_recurrencia_check
  CHECK (recurrencia = ANY (ARRAY[
    'ninguna'::text, 'diaria'::text, 'semanal'::text, 'mensual'::text,
    'bimestral'::text, 'trimestral'::text, 'anual'::text
  ]));

ALTER TABLE public.todo_tarea
  ADD CONSTRAINT todo_tarea_recurrencia_params_chk CHECK (
    (recurrencia = 'ninguna')
    OR (recurrencia = 'diaria')
    OR (recurrencia = 'semanal' AND dia_semana IS NOT NULL)
    OR (recurrencia IN ('mensual', 'bimestral', 'trimestral', 'anual') AND dia_mes IS NOT NULL)
  );

-- Ver migración aplicada en Supabase: función todo_next_dates + todo_crear_tarea
-- (mismo contenido que apply_migration todo_recurrencia_bimestral_trimestral).
