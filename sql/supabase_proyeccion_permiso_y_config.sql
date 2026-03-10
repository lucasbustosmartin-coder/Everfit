-- Proyección: permiso ver_proyeccion (Admin y Encargado) y tabla config_dashboard.
-- Ejecutar después de supabase_seguridad.sql en Supabase SQL Editor.

-- Permiso para ver y configurar la proyección (Admin y Encargado sí; Visor no)
INSERT INTO public.app_permission (permission, description) VALUES
  ('ver_proyeccion', 'Ver proyección de flujo y configurar método, meses, etc.')
ON CONFLICT (permission) DO NOTHING;

INSERT INTO public.app_role_permission (role, permission) VALUES
  ('admin', 'ver_proyeccion'),
  ('encargado', 'ver_proyeccion')
ON CONFLICT (role, permission) DO NOTHING;

-- Configuración de proyección por usuario (método, meses de historia, meses a proyectar, recorte)
CREATE TABLE IF NOT EXISTS public.config_dashboard (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  proyeccion_metodo text NOT NULL DEFAULT 'promedio_ponderado',
  proyeccion_meses int NOT NULL DEFAULT 6,
  proyeccion_cantidad int NOT NULL DEFAULT 3,
  proyeccion_recorte int NOT NULL DEFAULT 15,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.config_dashboard IS 'Config de proyección por usuario (Everfit). Solo usuarios con ver_proyeccion ven la proyección en el dashboard.';
COMMENT ON COLUMN public.config_dashboard.proyeccion_metodo IS 'promedio_ponderado | promedio | mediana | promedio_recortado';
COMMENT ON COLUMN public.config_dashboard.proyeccion_meses IS 'Meses de historia para valor típico: 3, 6, 12, 24';
COMMENT ON COLUMN public.config_dashboard.proyeccion_cantidad IS 'Meses futuros a proyectar: 1 a 12';
COMMENT ON COLUMN public.config_dashboard.proyeccion_recorte IS 'Recorte % por lado (promedio_recortado): 0, 5, 10, 15, 20, 25';

ALTER TABLE public.config_dashboard ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "config_dashboard_own" ON public.config_dashboard;
CREATE POLICY "config_dashboard_own"
  ON public.config_dashboard FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.config_dashboard TO authenticated;
