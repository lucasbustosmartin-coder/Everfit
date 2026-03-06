-- Vaciar la tabla base_everfit (para repoblar desde Excel)
-- Ejecutar en Supabase SQL Editor cuando se quiera volver a cargar desde Base_Everfit.xlsx

TRUNCATE TABLE public.base_everfit;

-- Si falla por restricciones (FK u otras), usar en su lugar:
-- DELETE FROM public.base_everfit;
