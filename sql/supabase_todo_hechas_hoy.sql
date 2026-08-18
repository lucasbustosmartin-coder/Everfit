-- Card «Hechas hoy»: instancias completadas en el día calendario Argentina (sin recorte por hora).
-- Independiente del filtro Estado=Abiertas (si no, la card nunca sube al marcar Hecha).

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
      ELSE COALESCE(up.email, i.responsable_user_id::text)
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
