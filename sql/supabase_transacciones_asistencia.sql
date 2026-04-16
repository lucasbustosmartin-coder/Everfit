-- Tabla: transacciones_asistencia
-- Importación desde Excel tipo "Transacciones" por sucursal (Cramer, Cabildo, Migueletes).
-- Ejecutar en Supabase SQL Editor del proyecto Everfit (después de supabase_seguridad.sql y has_permission).

CREATE TABLE IF NOT EXISTS public.transacciones_asistencia (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sucursal text NOT NULL,
  nombre text,
  apellido text,
  empleado_id text,
  fecha date,
  tiempo text,
  departamento text,
  semana text,
  temperatura_superficie_piel text,
  estado_temperatura text,
  tipo_pase_tarjeta text,
  metodo_verificacion text,
  punto_control_asistencia text,
  nombre_personalizado text,
  fuente_datos text,
  tipo_gestion text,
  comentario text,
  export_hora text,
  export_operador text,
  export_periodo text,
  origen_archivo text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transacciones_asistencia_sucursal ON public.transacciones_asistencia (sucursal);
CREATE INDEX IF NOT EXISTS idx_transacciones_asistencia_fecha ON public.transacciones_asistencia (fecha);
CREATE INDEX IF NOT EXISTS idx_transacciones_asistencia_empleado ON public.transacciones_asistencia (empleado_id);

COMMENT ON TABLE public.transacciones_asistencia IS 'Exportaciones de asistencia/transacciones por sucursal (Excel Sheet1).';

ALTER TABLE public.transacciones_asistencia ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "transacciones_asistencia_select_auth" ON public.transacciones_asistencia;
CREATE POLICY "transacciones_asistencia_select_auth"
  ON public.transacciones_asistencia FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "transacciones_asistencia_insert_upload" ON public.transacciones_asistencia;
CREATE POLICY "transacciones_asistencia_insert_upload"
  ON public.transacciones_asistencia FOR INSERT TO authenticated
  WITH CHECK (public.has_permission('upload_base'));

DROP POLICY IF EXISTS "transacciones_asistencia_delete_upload" ON public.transacciones_asistencia;
CREATE POLICY "transacciones_asistencia_delete_upload"
  ON public.transacciones_asistencia FOR DELETE TO authenticated
  USING (public.has_permission('upload_base'));
