-- Índice covering opcional: lecturas por rango de fecha (dashboard Asistencia)
-- sin volver al heap para las columnas usadas en el SELECT.
-- Ejecutar en Supabase SQL Editor si ya tenés la tabla (idempotente).
-- Requiere PostgreSQL 11+ (INCLUDE). Tras crearlo: ANALYZE public.transacciones_asistencia;

CREATE INDEX IF NOT EXISTS idx_transacciones_asistencia_fecha_covering
  ON public.transacciones_asistencia (fecha)
  INCLUDE (sucursal, tiempo, nombre, apellido, empleado_id);

COMMENT ON INDEX public.idx_transacciones_asistencia_fecha_covering IS
  'Cubre consultas ORDER BY fecha con rango; columnas del listado Asistencia en INCLUDE.';

ANALYZE public.transacciones_asistencia;
