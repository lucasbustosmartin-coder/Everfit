-- Alertas del Flujo por mes: umbral de desvío % vs mes anterior, por usuario.
-- Ejecutar después de supabase_proyeccion_permiso_y_config.sql en Supabase SQL Editor.

ALTER TABLE public.config_dashboard
  ADD COLUMN IF NOT EXISTS alerta_desvio_pct int NOT NULL DEFAULT 25;

ALTER TABLE public.config_dashboard
  DROP CONSTRAINT IF EXISTS config_dashboard_alerta_desvio_pct_chk;
ALTER TABLE public.config_dashboard
  ADD CONSTRAINT config_dashboard_alerta_desvio_pct_chk
  CHECK (alerta_desvio_pct IN (5, 10, 15, 20, 25, 30, 50));

COMMENT ON COLUMN public.config_dashboard.alerta_desvio_pct IS 'Alerta en Flujo por mes cuando un concepto (ingresos) o beneficiario (egresos) varía más de este % vs el mes anterior: 5, 10, 15, 20, 25, 30, 50';
