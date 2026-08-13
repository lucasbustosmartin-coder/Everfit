# Configuración – reasignar tareas (Everfit)

Menú **Configuración** (permiso `ver_configuracion`, por defecto Admin y Encargado; toggle en Seguridad).

Primera función: **reasignar** tareas To-Do de un responsable a otro (baja o ausencia).

## Uso

Dos solapas:

- **Por usuario:** origen y destino son usuarios concretos.
- **Por perfil:** origen y destino son perfiles (Recepcionista, Profesor, etc.).

Pasos:

1. Elegí origen y destino (distintos).
2. **Buscar** lista las tareas **abiertas** (pendiente / en curso, incluye vencidas efectivas).
3. Marcá una o varias filas y **Reasignar seleccionadas**, o **Reasignar todas**.

**Reasignar todas** mueve todas las ocurrencias abiertas de ese origen **y** las plantillas recurrentes activas, para que las próximas réplicas queden en el destino.

**Reasignar seleccionadas** mueve solo esas filas. Si no quedan ocurrencias abiertas de esa plantilla en el origen, también actualiza la plantilla.

Confirmación y avisos con mensajería interna (toast / modal), no del navegador.

## SQL

Ejecutar `sql/supabase_todo_reasignar.sql` (después de `sql/supabase_todo.sql`).

RPCs: `todo_list_para_reasignar`, `todo_reasignar`.
