# Sedes – catálogo ABM

Menú **Sedes** (solo Admin / permiso `assign_roles`): alta, edición, activar/desactivar sedes.

## Para qué sirve

1. Fuente de verdad del listado de sucursales en **Seguridad → Configurar** (sedes que puede ver cada usuario).
2. En **To-Do**: elegir una sede o **todas** (replica una instancia por sede activa).
3. Filtros del dashboard / asistencia siguen usando `get_sucursales_list()` (ahora lee el catálogo activo).

## Activación

Ejecutar `sql/supabase_sedes.sql` en Supabase (después de seguridad). Semilla inicial: Cabildo, Cramer, Migueletes (y distinct de `base_everfit` si había datos).

## RPCs

| RPC | Uso |
|-----|-----|
| `sedes_list_admin` | Listado ABM (incluye inactivas) |
| `sedes_upsert` | Alta / edición |
| `sedes_set_activa` | Activar / desactivar |
| `sedes_delete` | Baja lógica (`activa=false`) |
| `get_sucursales_list` | Nombres activos (Seguridad, To-Do, filtros) |

La baja es lógica para no romper historial de To-Do ni arrays `sucursales_permitidas` guardados por nombre.
