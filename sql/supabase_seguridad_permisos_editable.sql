-- Permisos por rol editables desde el dashboard (solo Admin).
-- Ejecutar después de supabase_seguridad.sql (y supabase_proyeccion_permiso_y_config.sql si usás proyección).
-- Asegura que app_permission tenga ver_proyeccion para que aparezca en la UI.

INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_proyeccion', 'Ver proyección de flujo y configurar método, meses, etc.')
ON CONFLICT (permission) DO NOTHING;

-- Admin: listar roles con sus permisos (granted = true/false) para la UI de configuración
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
  ORDER BY (CASE r.role WHEN 'admin' THEN 1 WHEN 'encargado' THEN 2 WHEN 'visor' THEN 3 ELSE 4 END), p.permission;
END;
$$;

-- Admin: activar o desactivar un permiso para un rol
CREATE OR REPLACE FUNCTION public.set_role_permission(p_role text, p_permission text, p_granted boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.has_permission('assign_roles') THEN
    RAISE EXCEPTION 'Sin permiso para modificar roles';
  END IF;
  IF p_granted THEN
    INSERT INTO public.app_role_permission (role, permission) VALUES (p_role, p_permission)
    ON CONFLICT (role, permission) DO NOTHING;
  ELSE
    DELETE FROM public.app_role_permission WHERE role = p_role AND permission = p_permission;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_roles_permissions_for_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_role_permission(text, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.get_roles_permissions_for_admin() IS 'Lista roles y permisos con granted; solo Admin (assign_roles).';
COMMENT ON FUNCTION public.set_role_permission(text, text, boolean) IS 'Activa o desactiva un permiso para un rol; solo Admin.';
