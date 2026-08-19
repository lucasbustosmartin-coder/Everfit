-- Menú Home (Dashboard): permiso ver_dashboard configurable por rol en Seguridad.
-- ver_asistencia ya existe (sql/supabase_asistencia_ver_permiso.sql).
-- Ejecutar después de supabase_seguridad.sql y supabase_seguridad_permisos_editable.sql.

INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_dashboard', 'Ver menú Home (Dashboard: flujo, resumen y gráficos)')
ON CONFLICT (permission) DO UPDATE SET description = EXCLUDED.description;

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'ver_dashboard'),
  ('encargado', 'ver_dashboard'),
  ('visor', 'ver_dashboard'),
  ('recepcionista', 'ver_dashboard'),
  ('profesor', 'ver_dashboard')
ON CONFLICT (role, permission) DO NOTHING;
