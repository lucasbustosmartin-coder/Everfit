-- Admin (assign_roles): editar nombre_usuario de cualquier usuario desde Seguridad.
-- Usuario: sigue pudiendo editar el propio vía set_my_nombre_usuario / Mi perfil.

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
