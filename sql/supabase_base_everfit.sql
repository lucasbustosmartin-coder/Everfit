-- Tabla: base_everfit
-- Migración desde Base/Base_Everfit.xlsx (hoja "Base") – Everfit
-- Ejecutar en Supabase SQL Editor antes de volcar datos

CREATE TABLE IF NOT EXISTS public.base_everfit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiario text,
  concepto text,
  centro_de_costos text,
  detalle text,
  medio text,
  nro_de_cheque text,
  fecha_emision date,
  fecha_original_pago date,
  fecha_pago date,
  importe numeric,
  observaciones text,
  orden_de_pago text,
  real_pendiente text,
  valor numeric,
  tc numeric,
  valor_usd numeric,
  sucursal text,
  ingresos_egresos text,
  mes_de_pago text,
  origen_archivo text,
  created_at timestamptz DEFAULT now()
);

-- Índices útiles para consultas
CREATE INDEX IF NOT EXISTS idx_base_everfit_fecha_pago ON public.base_everfit (fecha_pago);
CREATE INDEX IF NOT EXISTS idx_base_everfit_ingresos_egresos ON public.base_everfit (ingresos_egresos);
CREATE INDEX IF NOT EXISTS idx_base_everfit_sucursal ON public.base_everfit (sucursal);
CREATE INDEX IF NOT EXISTS idx_base_everfit_concepto ON public.base_everfit (concepto);
CREATE INDEX IF NOT EXISTS idx_base_everfit_centro_costos ON public.base_everfit (centro_de_costos);

COMMENT ON TABLE public.base_everfit IS 'Datos migrados desde Base_Everfit.xlsx (hoja Base).';
