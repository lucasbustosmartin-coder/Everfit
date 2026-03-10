-- RLS en tablas de roles y permisos (quitar aviso UNRESTRICTED en Table Editor).
-- Ejecutar en Supabase SQL Editor (proyecto Everfit).
-- Las RPC get_roles_permissions_for_admin y set_role_permission son SECURITY DEFINER,
-- así que siguen pudiendo leer/escribir; los usuarios autenticados solo pueden SELECT.

-- app_role: solo lectura para autenticados (catálogo de roles)
ALTER TABLE public.app_role ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_role_select_authenticated" ON public.app_role;
CREATE POLICY "app_role_select_authenticated"
  ON public.app_role FOR SELECT TO authenticated
  USING (true);

-- app_permission: solo lectura para autenticados (catálogo de permisos)
ALTER TABLE public.app_permission ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_permission_select_authenticated" ON public.app_permission;
CREATE POLICY "app_permission_select_authenticated"
  ON public.app_permission FOR SELECT TO authenticated
  USING (true);

-- app_role_permission: solo lectura para autenticados (qué rol tiene qué permiso)
-- Los cambios los hace solo Admin vía RPC set_role_permission (SECURITY DEFINER)
ALTER TABLE public.app_role_permission ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_role_permission_select_authenticated" ON public.app_role_permission;
CREATE POLICY "app_role_permission_select_authenticated"
  ON public.app_role_permission FOR SELECT TO authenticated
  USING (true);
