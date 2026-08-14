-- Una tarea diaria no se puede marcar Hecha antes de su vencimiento.
-- Prerrequisito: sql/supabase_todo.sql

CREATE OR REPLACE FUNCTION public.todo_cambiar_estado(p_instancia_id uuid, p_estado text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  i public.todo_instancia%ROWTYPE;
  v_rec text;
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

  IF p_estado = 'hecha' THEN
    SELECT COALESCE(t.recurrencia, 'ninguna') INTO v_rec
    FROM public.todo_tarea t
    WHERE t.id = i.tarea_id;
    IF COALESCE(v_rec, 'ninguna') = 'diaria' AND i.vencimiento_at > now() THEN
      RAISE EXCEPTION 'Esta tarea diaria se puede dar por hecha a partir de su hora de vencimiento';
    END IF;
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

GRANT EXECUTE ON FUNCTION public.todo_cambiar_estado(uuid, text) TO authenticated;
