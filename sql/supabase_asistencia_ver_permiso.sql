-- Vista Asistencia: permiso ver_asistencia (aparece en Seguridad → Permisos por rol) y RLS de lectura.
-- Ejecutar en Supabase SQL Editor **después** de:
--   supabase_seguridad.sql (has_permission, get_my_permissions)
--   supabase_transacciones_asistencia.sql (tabla transacciones_asistencia)
--   supabase_seguridad_permisos_editable.sql (get_roles_permissions_for_admin / set_role_permission), si usás toggles en el dashboard.
--
-- Por defecto los tres roles tienen ver_asistencia; el Admin puede quitarlo por rol desde la app.

INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_asistencia', 'Ver menú Asistencia, transacciones y reportes de concurrencia')
ON CONFLICT (permission) DO NOTHING;

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'ver_asistencia'),
  ('encargado', 'ver_asistencia'),
  ('visor', 'ver_asistencia')
ON CONFLICT (role, permission) DO NOTHING;

DROP POLICY IF EXISTS "transacciones_asistencia_select_auth" ON public.transacciones_asistencia;
CREATE POLICY "transacciones_asistencia_select_auth"
  ON public.transacciones_asistencia FOR SELECT TO authenticated
  USING (public.has_permission('ver_asistencia'));
