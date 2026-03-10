-- Módulo de Seguridad – Everfit
-- Roles (Admin, Encargado, Visor), permisos por rol, perfiles de usuario.
-- Ejecutar en Supabase SQL Editor (proyecto Everfit) después de tener base_everfit y Auth habilitado.

-- ========== 1. Tablas ==========

-- Perfiles públicos (id + email); se llena con trigger al registrarse
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON public.user_profiles (email);

-- Roles de la app
CREATE TABLE IF NOT EXISTS public.app_role (
  role text PRIMARY KEY,
  label text NOT NULL
);

INSERT INTO public.app_role (role, label) VALUES
  ('admin', 'Admin'),
  ('encargado', 'Encargado'),
  ('visor', 'Visor')
ON CONFLICT (role) DO NOTHING;

-- Permisos (qué puede hacer cada rol)
CREATE TABLE IF NOT EXISTS public.app_permission (
  permission text PRIMARY KEY,
  description text
);

INSERT INTO public.app_permission (permission, description) VALUES
  ('upload_base', 'Actualizar base (truncar y cargar Excel)'),
  ('assign_roles', 'Asignar perfiles a usuarios')
ON CONFLICT (permission) DO NOTHING;

-- Qué rol tiene qué permiso
CREATE TABLE IF NOT EXISTS public.app_role_permission (
  role text NOT NULL REFERENCES public.app_role(role) ON DELETE CASCADE,
  permission text NOT NULL REFERENCES public.app_permission(permission) ON DELETE CASCADE,
  PRIMARY KEY (role, permission)
);

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'upload_base'),
  ('admin', 'assign_roles'),
  ('encargado', 'upload_base')
ON CONFLICT (role, permission) DO NOTHING;
-- Visor no tiene permisos extra (solo ver dashboard).

-- Perfil de cada usuario: su rol en la app (solo Admin asigna esto)
CREATE TABLE IF NOT EXISTS public.app_user_profile (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL REFERENCES public.app_role(role) DEFAULT 'visor',
  updated_at timestamptz DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_app_user_profile_role ON public.app_user_profile (role);

COMMENT ON TABLE public.app_user_profile IS 'Rol de cada usuario; solo Admin puede modificar.';
COMMENT ON TABLE public.app_role_permission IS 'upload_base: solo Admin y Encargado; assign_roles: solo Admin.';

-- ========== 2. Trigger: al registrarse un usuario, crear fila en user_profiles ==========

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.user_profiles (id, email)
  VALUES (NEW.id, COALESCE(NEW.email, ''));
  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Para usuarios ya existentes antes del trigger: sincronizar una vez
INSERT INTO public.user_profiles (id, email)
SELECT id, COALESCE(email, '') FROM auth.users
ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;

-- ========== 3. Funciones de permisos ==========

-- Rol del usuario actual (para uso en RLS y RPC)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT role FROM public.app_user_profile WHERE user_id = auth.uid();
$$;

-- Verificar si el usuario actual tiene un permiso
CREATE OR REPLACE FUNCTION public.has_permission(perm text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.app_role_permission rp
    JOIN public.app_user_profile u ON u.role = rp.role
    WHERE u.user_id = auth.uid() AND rp.permission = perm
  );
$$;

-- RPC para el front: devolver permisos del usuario actual (ej. ['upload_base', 'assign_roles'])
CREATE OR REPLACE FUNCTION public.get_my_permissions()
RETURNS text[]
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(array_agg(rp.permission), ARRAY[]::text[])
  FROM public.app_role_permission rp
  JOIN public.app_user_profile u ON u.role = rp.role
  WHERE u.user_id = auth.uid();
$$;

-- RPC para Admin: listar usuarios con email y rol (solo si tiene assign_roles)
CREATE OR REPLACE FUNCTION public.get_users_for_admin()
RETURNS TABLE (user_id uuid, email text, role text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p.id, p.email, COALESCE(u.role, 'visor')
  FROM public.user_profiles p
  LEFT JOIN public.app_user_profile u ON u.user_id = p.id
  WHERE public.has_permission('assign_roles');
$$;

-- ========== 3b. RLS en tablas de catálogo (roles y permisos) ==========
-- Quita el aviso UNRESTRICTED; solo lectura para autenticados. Escritura vía RPC (SECURITY DEFINER).

ALTER TABLE public.app_role ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_role_select_authenticated" ON public.app_role;
CREATE POLICY "app_role_select_authenticated"
  ON public.app_role FOR SELECT TO authenticated USING (true);

ALTER TABLE public.app_permission ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_permission_select_authenticated" ON public.app_permission;
CREATE POLICY "app_permission_select_authenticated"
  ON public.app_permission FOR SELECT TO authenticated USING (true);

ALTER TABLE public.app_role_permission ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "app_role_permission_select_authenticated" ON public.app_role_permission;
CREATE POLICY "app_role_permission_select_authenticated"
  ON public.app_role_permission FOR SELECT TO authenticated USING (true);

-- ========== 4. RLS en user_profiles ==========

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_profiles_select_own" ON public.user_profiles;
CREATE POLICY "user_profiles_select_own"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "user_profiles_select_admin" ON public.user_profiles;
CREATE POLICY "user_profiles_select_admin"
  ON public.user_profiles FOR SELECT TO authenticated
  USING (public.has_permission('assign_roles'));

-- Usuario puede insertar/actualizar su propia fila (por si el trigger no corrió)
DROP POLICY IF EXISTS "user_profiles_insert_own" ON public.user_profiles;
CREATE POLICY "user_profiles_insert_own"
  ON public.user_profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());
DROP POLICY IF EXISTS "user_profiles_update_own" ON public.user_profiles;
CREATE POLICY "user_profiles_update_own"
  ON public.user_profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ========== 5. RLS en app_user_profile ==========

ALTER TABLE public.app_user_profile ENABLE ROW LEVEL SECURITY;

-- Cualquiera autenticado puede leer su propio rol
DROP POLICY IF EXISTS "app_user_profile_select_own" ON public.app_user_profile;
CREATE POLICY "app_user_profile_select_own"
  ON public.app_user_profile FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Solo quien tiene assign_roles puede ver todos los perfiles
DROP POLICY IF EXISTS "app_user_profile_select_admin" ON public.app_user_profile;
CREATE POLICY "app_user_profile_select_admin"
  ON public.app_user_profile FOR SELECT TO authenticated
  USING (public.has_permission('assign_roles'));

-- Solo quien tiene assign_roles puede insertar/actualizar (asignar roles)
DROP POLICY IF EXISTS "app_user_profile_insert_admin" ON public.app_user_profile;
CREATE POLICY "app_user_profile_insert_admin"
  ON public.app_user_profile FOR INSERT TO authenticated
  WITH CHECK (public.has_permission('assign_roles'));

-- Usuario nuevo puede asignarse a sí mismo rol 'visor' si aún no tiene perfil (una sola vez)
DROP POLICY IF EXISTS "app_user_profile_insert_self_visor" ON public.app_user_profile;
CREATE POLICY "app_user_profile_insert_self_visor"
  ON public.app_user_profile FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND role = 'visor'
    AND NOT EXISTS (SELECT 1 FROM public.app_user_profile WHERE app_user_profile.user_id = auth.uid())
  );

DROP POLICY IF EXISTS "app_user_profile_update_admin" ON public.app_user_profile;
CREATE POLICY "app_user_profile_update_admin"
  ON public.app_user_profile FOR UPDATE TO authenticated
  USING (public.has_permission('assign_roles'))
  WITH CHECK (public.has_permission('assign_roles'));

-- ========== 6. base_everfit: lectura solo autenticados; escritura solo con permiso upload_base ==========

ALTER TABLE public.base_everfit ENABLE ROW LEVEL SECURITY;

-- Quitar política de lectura anon (obligar login)
DROP POLICY IF EXISTS "base_everfit_select_anon" ON public.base_everfit;

DROP POLICY IF EXISTS "base_everfit_select_authenticated" ON public.base_everfit;
CREATE POLICY "base_everfit_select_authenticated"
  ON public.base_everfit FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "base_everfit_insert_with_upload" ON public.base_everfit;
CREATE POLICY "base_everfit_insert_with_upload"
  ON public.base_everfit FOR INSERT TO authenticated
  WITH CHECK (public.has_permission('upload_base'));

DROP POLICY IF EXISTS "base_everfit_delete_with_upload" ON public.base_everfit;
CREATE POLICY "base_everfit_delete_with_upload"
  ON public.base_everfit FOR DELETE TO authenticated
  USING (public.has_permission('upload_base'));

-- tipo_de_cambio: si existe, lectura para autenticados
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tipo_de_cambio') THEN
    ALTER TABLE public.tipo_de_cambio ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "tipo_de_cambio_select_authenticated" ON public.tipo_de_cambio;
    CREATE POLICY "tipo_de_cambio_select_authenticated"
      ON public.tipo_de_cambio FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ========== 7. Permisos para authenticated ==========

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON public.app_role TO authenticated;
GRANT SELECT ON public.app_permission TO authenticated;
GRANT SELECT ON public.app_role_permission TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.user_profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.app_user_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_permissions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_users_for_admin() TO authenticated;
